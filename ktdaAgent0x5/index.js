import 'dotenv/config';
import pkg from 'whatsapp-web.js';
const { Client, LocalAuth } = pkg;
import csv from 'csv-parser';
import fs from 'node:fs';
import axios from 'axios';
import { OpenAI } from 'openai';
import { systemPrompt } from './systemPrompt.js';
import { getContext } from './context.js';
import qrcode from 'qrcode-terminal';

// Log environment variables
console.log('DEEPSEEK_API_KEY:', process.env.DEEPSEEK_API_KEY);
// console.log('DEEPSEEK_BASE_URL:', process.env.DEEPSEEK_BASE_URL);

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
const ADMIN_NUMBER = '254795536131';

const openai = new OpenAI({
    baseURL: 'https://api.deepseek.com/v1',
    apiKey: DEEPSEEK_API_KEY
});

let communicationhistoryList = [{"contact": "contact","role":"role", "content":"content"}];

// console.log('OpenAI Config:', openai.baseURL, openai.apiKey);
console.log('OpenAI API Initialized with deepseek creds...');

async function getResponseFromDeepSeek(userQuery) {
    console.log('Sending query to DeepSeek:', userQuery); // Debug
    const completion = await openai.chat.completions.create({
        messages: [{ role: "system", content: systemPrompt }, { role: "user", content: userQuery }],
        model: "deepseek-chat",
    });
    // console.log('DeepSeek Response:', completion.choices[0].message.content); // Debug
    return completion.choices[0].message.content;
}

// Rest of your code remains unchanged...


class WhatsAppBot {
    constructor() {
        this.userSessions = new Map();
        this.initializeWhatsAppClient();
    }

    initializeWhatsAppClient() {
        this.client = new Client({
            authStrategy: new LocalAuth(),
            puppeteer: {
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            }
        });

        // this.client = new Client({ authStrategy: new LocalAuth() });

        this.client.on('qr', (qr) => {
            console.log('QR code required. Scan it:', qr);
            qrcode.generate(qr, { small: true });
          });
        // Event when authentication is successful
        this.client.on('authenticated', () => {
            console.log('Client is authenticated!');
        });
        
        // Event when the client is fully ready
        this.client.on('ready', () => {
            console.log('Client is ready and fully authenticated!');
        });
        
        // Event for authentication failure
        this.client.on('auth_failure', (msg) => {
            console.error('Authentication failed:', msg);
        });
        
        // Initialize the client
        this.client.on('message', this.handleMessage.bind(this));
        this.client.initialize();
        console.log('Client initialized...');
    }

    async handleMessage(msg) {
        
        // Basic conversion
        const userNumber = msg.from;

        // get the history of communication with the person and turn it into a sting
        const userMessagesContext = communicationhistoryList.filter(item => item.contact === userNumber);
        const commsHistoryString = JSON.stringify(userMessagesContext);

        console.log('Message from:', userNumber, msg.body);
        const contact = await this.client.getContactById(userNumber);
        const displayName = contact.pushname || 'Customer';
        const userInput = msg.body.trim();

        if (msg.body !== 'typing') {
            const chat = await this.client.getChatById(msg.from);
            chat.sendStateTyping(); // Start typing indicator
            setTimeout(() => {
                chat.clearState();  // Clear typing status after 25 seconds
            }, 25000);
        }
        
        // const context = await getContext(userInput);

        communicationhistoryList.push({"contact":userNumber,"role":"user", "content":userInput});
        // console.log('Context has been found:', context);
        // const query = userInput + " with this context " + context;
        // const query = ` context: ${context}
        //                 chatHistory: ${commsHistoryString}
        //                 question:` + userInput;
        const query = ` chatHistory: ${commsHistoryString} question:` + userInput;

        const response = await getResponseFromDeepSeek(query);
        console.log('Response from DeepSeek:', response);
        communicationhistoryList.push({"contact":userNumber,"role":"system", "content":response});
        msg.reply(response);
    }
}

const whatsAppBot = new WhatsAppBot();
console.log('Advanced WhatsApp Product Suggestion Bot Started...');