import 'dotenv/config';
import pkg from 'whatsapp-web.js';
const { Client, LocalAuth } = pkg;
import csv from 'csv-parser';
import fs from 'node:fs';
import axios from 'axios';
import { OpenAI } from 'openai';
import { systemPrompt } from './systemPrompt.js';
import qrcode from 'qrcode-terminal';

console.log('DEEPSEEK_API_KEY:', process.env.DEEPSEEK_API_KEY.substring(0, 7) + '...'); // Log only the first 4 characters for security

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

const openai = new OpenAI({
    baseURL: 'https://api.deepseek.com/v1',
    apiKey: DEEPSEEK_API_KEY
});

let communicationhistoryList = [{"contact": "contact", "role": "role", "content": "content"}];

console.log('OpenAI API Initialized with deepseek creds...');

async function getResponseFromDeepSeek(userQuery) {
    console.log('Sending query to DeepSeek:', userQuery);
    try {
        const completion = await openai.chat.completions.create({
            messages: [{ role: "system", content: systemPrompt }, { role: "user", content: userQuery }],
            model: "deepseek-chat",
        });
        return completion.choices[0].message.content;
    } catch (error) {
        console.error('Error calling DeepSeek API:', error);
        return 'Sorry, something went wrong. Please try again later.    We did not get a response from deepseek';
    }
}

class WhatsAppBot {
    constructor() {
        // this.userSessions = new Map();
        this.initializeWhatsAppClient();
    }

    initializeWhatsAppClient() {
        this.client = new Client({
            authStrategy: new LocalAuth(),
            puppeteer: {
                headless: true,
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            }
        });

        this.client.on('qr', (qr) => {
            console.log('QR code required. Scan it:');
            qrcode.generate(qr, { small: true });
        });

        this.client.on('authenticated', () => {
            console.log('Client is authenticated!');
        });

        this.client.on('ready', () => {
            console.log('Client is ready and fully authenticated!');
        });

        this.client.on('auth_failure', (msg) => {
            console.error('Authentication failed:', msg);
        });

        this.client.on('message', this.handle_NewMessage.bind(this));
        this.client.initialize();
        console.log('Client initialized...');
    }

    async handle_NewMessage(msg) {
        if (!msg || !msg.from || !msg.reply) {
            console.error('Invalid message object:', msg);
            return;
        }

        const userNumber = msg.from;
        const userMessagesContext = communicationhistoryList.filter(item => item.contact === userNumber);
        const commsHistoryString = JSON.stringify(userMessagesContext);

        console.log('Message from:', userNumber, 'Body:', msg.body);
        try {
            const contact = await this.client.getContactById(userNumber);
            const displayName = contact.pushname || 'Customer';
            const userInput = msg.body.trim();

            if (msg.body !== 'typing') {
                const chat = await this.client.getChatById(msg.from);
                console.log('Chat object:', chat);
                chat.sendStateTyping();
                setTimeout(() => {
                    chat.clearState();
                }, 25000);
            }

            communicationhistoryList.push({"contact": userNumber, "role": "user", "content": userInput});
            const query = `chatHistory: ${commsHistoryString} question: ${userInput}`;

            const response = await getResponseFromDeepSeek(query);
            console.log('Response from DeepSeek:', response);
            communicationhistoryList.push({"contact": userNumber, "role": "system", "content": response});

            await msg.reply(response);
        } catch (error) {
            console.error('Error handling message:', error);
            await msg.reply('Sorry, an error occurred. Please try again.');
        }
    }
}

const whatsAppBot = new WhatsAppBot();
console.log('Advanced WhatsApp Product Suggestion Bot Started...');
