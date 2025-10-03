import { GoogleGenerativeAI } from "@google/generative-ai";
const genAI = new GoogleGenerativeAI(process.env.API_KEY);
const model = genAI.getGenerativeModel({ 
  model: "gemini-2.0-flash-exp",
  generationConfig: {
    maxOutputTokens: 8192,
  }
});
const prompt = process.env.LLM_PROMPT;

try {
  const result = await model.generateContent(prompt);
  console.log(result.response.text());
} catch (error) {
  console.log('Next awesome release');
}
