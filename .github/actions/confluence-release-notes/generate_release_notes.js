class ReleaseNotesGenerator {
  constructor(issue_provider, template, categorizationProvider) {
    this.issue_provider = issue_provider;
    this.template = template;
    this.categorizationProvider = categorizationProvider;
  }

  generateReleaseNotes(jira_ticket_data) {
    const { issues } = jira_ticket_data;
    const data = this.calculateReleaseData(issues);
    const release_notes = this.fromTemplate(data);
    return release_notes;
  }

  calculateReleaseData(issues) {
    const features = [];
    const bugs = [];
    const improvements = [];
    for (const issue of issues) {
      const { key: ticket_id, fields } = issue;
      const {
        summary,
        customfield_11628: additional_resources,
        customfield_11627: stakeholder_highlight_data,
        issuetype,
      } = fields;
      const type = issuetype.name;
      const stakeholder_highlight = !!stakeholder_highlight_data?.length;
      if (this.isFeature(ticket_id, type, summary)) {
        features.push({
          ticket_id,
          summary,
          impact_summary: this.extractImpactSummary(issue),
          additional_resources,
          stakeholder_highlight,
        });
      } else if (this.isBug(ticket_id, type, summary)) {
        bugs.push({
          ticket_id,
          summary,
          impact_summary: this.extractImpactSummary(issue),
          additional_resources,
          stakeholder_highlight,
        });
      } else if (this.isImprovement(ticket_id, type, summary)) {
        improvements.push({
          ticket_id,
          summary,
          impact_summary: this.extractImpactSummary(issue),
          additional_resources,
          stakeholder_highlight,
        });
      }
    }
    return { features, bugs, improvements };
  }

  fromTemplate(data) {
    const createRow = ({
      ticket_id,
      summary,
      impact_summary,
      additional_resources,
      stakeholder_highlight,
    }) => {
      return `<tr><td style="text-align: center;"><a href="https://virdocs.atlassian.net/browse/${ticket_id}">${ticket_id}</a></td><td style="text-align: center;">${summary}</td><td style="text-align: center;">${
        impact_summary ?? ""
      }</td><td style="text-align: center;">${
        additional_resources
          ? `<a href="${additional_resources}">${additional_resources}</a>`
          : ""
      }</td><td style="text-align: center;">${
        stakeholder_highlight ? "✅" : ""
      }</td></tr>`;
    };
    const features = data.features.map(createRow).join("\n    ");
    const bugs = data.bugs.map(createRow).join("\n");
    const improvements = data.improvements.map(createRow).join("\n");
    const updatedTemplate = this.template
      .replace("<!--FEATURES-->", features)
      .replace("<!--BUGS-->", bugs)
      .replace("<!--IMPROVEMENTS-->", improvements);
    return updatedTemplate;
  }

  isFeature(key, type) {
    return false;
  }

  isBug(key, type) {
    return type === "Bug";
  }

  isImprovement(key, type) {
    return type !== "Bug";
  }

  extractImpactSummary(issue) {
    const { fields } = issue;
    const { customfield_11625: impact } = fields;
    if (impact) {
      return impact;
    }
    return this.getParentImpactSummary(issue);
  }

  getParentImpactSummary(issue) {
    const parent = this.getParentJiraTicket(issue);
    if (parent) {
      const { fields } = parent;
      const { customfield_11625: impact } = fields;
      if (impact) {
        return impact;
      }
      return this.getParentImpactSummary(parent);
    }
    return null;
  }

  getParentJiraTicket(issue) {
    const { fields } = issue;
    const { parent } = fields;
    if (parent) {
      const { key: parent_key } = parent;
      return this.issue_provider.getIssue(parent_key);
    }
    return null;
  }
}

class CategorizationProvider {
  constructor(jiraTickets, llmClient) {
    this.jiraTickets = jiraTickets;
    this.llmClient = llmClient;
    this.categories = {};
  }

  async categorizeTickets() {
    const ticketsToCategorize = this.jiraTickets.filter(
      (ticket) => ticket.fields.issuetype.name !== "Bug"
    );
    if (ticketsToCategorize.length === 0) return;
    const ticket_data = this.preparePrompt(ticketsToCategorize);
    const response = await this.callLLM(ticket_data);
    if (response && response.categories) {
      response.categories.forEach(({ ticket_id, category }) => {
        this.categories[ticket_id] = category;
      });
    }
  }

  preparePrompt(tickets) {
    return tickets.map((ticket) => ({
      key: ticket.key,
      summary: ticket.fields.summary,
      type: ticket.fields.issuetype.name,
    }));
  }

  async callLLM(data) {
    try {
      const response = await this.llmClient.sendRequest(data);
      return response;
    } catch (error) {
      console.error("Error calling LLM", error);
      throw error;
    }
  }

  isFeature(key) {
    if (this.categories[key] === undefined) {
      return true;
    }
    return this.categories[key] === "Feature";
  }

  isImprovement(key) {
    if (this.categories[key] === undefined) {
      return false;
    }
    return this.categories[key] === "Improvement";
  }
}

class SimpleLogicClient {
  constructor() {}
  async sendRequest(data) {
    const categories = data.map(({ summary, type }) => {
      const category = "Improvement";
      return {
        ticket_id: summary,
        category,
      };
    });
    return { categories };
  }
}

class GeminiClient {
  constructor(api_key, fetch) {
    this.api_key = api_key;
    this.fetch = fetch;
  }
  async sendRequest(data) {
    const command =
      'Categorize the following as either Improvement or Feature and output to json using schema \'{"categories":[{"ticket_id":"$key","category":"$category"}]}\'';
    const url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-8b:generateContent?key=" +
      this.api_key;
    const body = JSON.stringify({
      contents: [
        {
          parts: [
            {
              text: `${command}\n${JSON.stringify(data)}`,
            },
          ],
        },
      ],
    });
    const response = await this.fetch(url, {
      method: "POST",
      body,
      headers: {
        "Content-Type": "application/json",
      },
    });

    const generatedText = response.candidates[0].content.parts[0].text;
    // remove ```json and ```
    const json = generatedText.replace("```json", "").replace("```", "");
    return JSON.parse(json);
  }
}

class JiraTicketProvider {
  constructor(runCmd, scriptPath) {
    this.runCmd = runCmd;
    this.scriptPath = scriptPath;
  }
  getIssue(key) {
    const result = this.runCmd(this.scriptPath, [key]);
    return JSON.parse(result.stdout);
  }
}

function runCmd(cmd, args, env) {
  const { spawnSync } = require("child_process");
  const result = spawnSync(cmd, args, { env, stdio: "pipe" });
  if (result.error) {
    throw new Error(result.error);
  }
  if (result.status !== 0) {
    throw new Error(`Command failed with status ${result.status}`);
  }
  return result;
}

module.exports = {
  ReleaseNotesGenerator,
  CategorizationProvider,
  SimpleLogicClient,
  GeminiClient,
  runCmd,
};

function main(input_file, output_file) {
  const fs = require("fs");
  const path = require("path");
  const {
    ReleaseNotesGenerator,
    CategorizationProvider,
    SimpleLogicClient,
  } = require("./generate_release_notes");
  const template = fs.readFileSync(
    path.resolve(__dirname, "./templates/release_notes_template.html"),
    "utf8"
  );
  const jira_ticket_data = JSON.parse(fs.readFileSync(input_file, "utf8"));
  const categorizationProvider = new CategorizationProvider(
    jira_ticket_data.issues,
    new SimpleLogicClient(["fix", "improve", "enhance"])
  );
  categorizationProvider.categorizeTickets();
  const issueProvider = new JiraTicketProvider(
    runCmd,
    path.resolve(__dirname, "./jira_get_ticket.sh")
  );
  const releaseNotesGenerator = new ReleaseNotesGenerator(
    issueProvider,
    template,
    categorizationProvider
  );
  const release_notes =
    releaseNotesGenerator.generateReleaseNotes(jira_ticket_data);
  fs.writeFileSync(output_file, release_notes);
  console.log(`Release notes written to ${output_file}`);
}

if (require.main === module) {
  if (process.argv.length !== 4) {
    console.error(
      "Usage: node generate_release_notes.js <input_file> <output_file>"
    );
    process.exit(1);
  }
  main(process.argv[2], process.argv[3]);
}
