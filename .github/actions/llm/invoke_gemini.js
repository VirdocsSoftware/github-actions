import { GoogleGenerativeAI } from "@google/generative-ai";
const genAI = new GoogleGenerativeAI(process.env.API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
const prompt = process.env.LLM_PROMPT;

const result = await model.generateContent(prompt);
console.log(result.response.text());
