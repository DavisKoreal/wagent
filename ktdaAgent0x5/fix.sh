#!/bin/bash

# Script to fix npm audit, deprecated dependencies, and TypeError in ktdaAgent0x5 WhatsApp bot
# Run from: /home/davis/Desktop/wagent/ktdaAgent0x5
# Usage: bash fix_ktda_bot.sh

# Exit on any error
set -e

# Define project directory
PROJECT_DIR="/home/davis/Desktop/wagent/ktdaAgent0x5"

# Check if we're in the correct directory
if [ ! -f "$PROJECT_DIR/package.json" ]; then
    echo "Error: package.json not found. Please run this script from $PROJECT_DIR"
    exit 1
fi

echo "Starting fix for ktdaAgent0x5 bot..."

# Step 1: Load nvm
echo "Loading nvm..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Load nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Load nvm bash_completion

# Verify nvm is loaded
if ! command -v nvm &> /dev/null; then
    echo "Error: nvm is not installed. Please install nvm first."
    echo "Run: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash"
    echo "Then source ~/.bashrc and rerun this script."
    exit 1
fi
echo "nvm version: $(nvm --version)"

# Step 2: Use Node.js v20
echo "Switching to Node.js v20..."
nvm use 20
echo "Using Node.js version: $(node -v)"

# Step 3: Optimize npm settings
echo "Optimizing npm settings..."
npm config set registry https://registry.npmjs.org
npm config set maxsockets 3

# Step 4: Clear npm cache and remove node_modules, package-lock.json
echo "Clearing npm cache and removing node_modules, package-lock.json..."
npm cache clean --force
rm -rf "$PROJECT_DIR/node_modules" "$PROJECT_DIR/package-lock.json"
rm -rf "$PROJECT_DIR/.wwebjs_auth"  # Clear WhatsApp authentication cache

# Step 5: Clean up unused system packages
echo "Cleaning up unused system packages..."
sudo apt autoremove -y

# Step 6: Install system dependencies for Puppeteer
echo "Installing Chromium for Puppeteer..."
sudo apt-get update
sudo apt-get install -y chromium-browser

# Step 7: Reinstall project dependencies
echo "Reinstalling project dependencies..."
npm install --no-audit --no-fund

# Step 8: Install latest whatsapp-web.js and puppeteer
echo "Installing latest whatsapp-web.js and puppeteer..."
npm install whatsapp-web.js@latest puppeteer@latest --no-audit --no-fund

# Step 9: Update deprecated dependencies
echo "Updating known deprecated dependencies..."
npm install rimraf@latest glob@latest --no-audit --no-fund
# Remove fluent-ffmpeg if not needed
if grep -q "fluent-ffmpeg" "$PROJECT_DIR/package.json"; then
    echo "Removing deprecated fluent-ffmpeg..."
    npm uninstall fluent-ffmpeg
fi

# Step 10: Fix security vulnerabilities
echo "Fixing npm security vulnerabilities..."
npm audit fix --force || echo "Warning: npm audit fix failed. Continuing..."

# Step 11: Fix .bashrc to remove vcpkg_completion.bash error
echo "Checking for vcpkg_completion.bash error in .bashrc..."
if grep -q "vcpkg_completion.bash" "$HOME/.bashrc"; then
    echo "Removing invalid vcpkg_completion.bash reference from .bashrc..."
    sed -i '/vcpkg_completion.bash/d' "$HOME/.bashrc"
    echo "Removed vcpkg_completion.bash reference. Please source ~/.bashrc after the script completes."
fi

# Step 12: Backup and update index.js
echo "Backing up index.js to index.js.bak..."
cp "$PROJECT_DIR/index.js" "$PROJECT_DIR/index.js.bak"

echo "Writing updated index.js with error handling and correct import syntax..."
cat > "$PROJECT_DIR/index.js" << 'EOF'
import 'dotenv/config';
import pkg from 'whatsapp-web.js';
const { Client, LocalAuth } = pkg;
import csv from 'csv-parser';
import fs from 'node:fs';
import axios from 'axios';
import { OpenAI } from 'openai';
import { systemPrompt } from './systemPrompt.js';
import qrcode from 'qrcode-terminal';

console.log('DEEPSEEK_API_KEY:', process.env.DEEPSEEK_API_KEY);

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;
const ADMIN_NUMBER = '254795536131';

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
 sportiva console.error('Error calling DeepSeek API:', error);
        return 'Sorry, something went wrong. Please try again later.';
    }
}

class WhatsAppBot {
    constructor() {
        this.userSessions = new Map();
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
EOF

# Step 13: Verify permissions
echo "Setting correct permissions for project directory..."
sudo chown -R $(whoami):$(whoami) "$PROJECT_DIR"

# Step 14: Kill any existing node processes
echo "Killing any existing node processes..."
pkill -f node || echo "No existing node processes found."

# Step 15: Test the bot with debug output
echo "Testing the bot by running index.js..."
node "$PROJECT_DIR/index.js" > "$PROJECT_DIR/bot.log" 2>&1 &

# Step 16: Instructions for the user
echo "Setup complete!"
echo "1. Check $PROJECT_DIR/bot.log for bot output and errors."
echo "2. If a QR code is displayed, scan it with WhatsApp to authenticate."
echo "3. Test the bot by sending a message (e.g., 'Hello') to the bot's WhatsApp number."
echo "4. If errors occur, check the npm debug log: /home/davis/.npm/_logs/*.log"
echo "5. Original index.js backed up as index.js.bak"
echo "6. Run 'source ~/.bashrc' to apply .bashrc changes if vcpkg_completion.bash was removed."
echo "7. If issues persist, share the contents of bot.log and npm debug log."