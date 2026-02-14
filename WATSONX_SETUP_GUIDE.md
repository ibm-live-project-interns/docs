# IBM Watsonx API Setup Guide

## Credits

This comprehensive guide was provided by **Ishita**. Thank you for making AI-powered alert analysis accessible to everyone!

---

## Overview

This guide will walk you through setting up IBM Watsonx AI for the **ai-core** service in our Network Management MVP. You'll learn how to:

- Register for IBM Cloud with **no credit card required**
- Get free access using Academic Feature Codes
- Create your Watsonx API credentials
- Configure the `.env` file for the ai-core service

> **Best Part:** Completely free for students and educators using IBM's Academic Initiative program!

---

## Prerequisites

- **Email address** (preferably institutional/academic email)
- **Internet connection**
- **Basic understanding** of environment variables and configuration files
- **Access** to the project repository

---

## Step 1: Register on IBM Cloud (No Credit Card)

IBM provides **Academic Feature Codes** that grant free access to IBM Cloud services without requiring payment details.

### 1. Request an IBM Cloud Feature Code

The feature code process takes only a few minutes and provides instant access.

**[How to Request an IBM Cloud Feature Code](https://github.com/academic-initiative/documentation/tree/main/academic-initiative/how-to/How-to-request-and-IBM-Cloud-Feature-Code)**

**What happens next?**

- Submit your request through the link above
- You'll receive a **feature code via email** (usually within minutes to a few hours)
- Keep this code handy for the next step

> **Tip:** Check your spam folder if you don't see the email within an hour. The subject line typically contains "IBM Cloud Feature Code".

### 2. Create IBM Cloud Account Using Feature Code

Once you have your feature code, apply it while creating your IBM Cloud account.

**[How to Create an IBM Cloud Account](https://github.com/academic-initiative/documentation/tree/main/academic-initiative/how-to/How-to-create-an-IBM-Cloud-account)**

**Important notes:**

- No credit card required
- You'll get access to IBM Cloud services including watsonx.ai
- The feature code unlocks premium services for educational use
- Keep your IBM Cloud credentials secure

> **Success Check:** After registration, you should be able to log in to [cloud.ibm.com](https://cloud.ibm.com) and see the IBM Cloud dashboard.

---

## Step 2: Create Your Watsonx API Key

Now that you have access to IBM Cloud, you need to create an API key that the ai-core service will use to authenticate.

### 1. Navigate to API Key Management

1. Log in to [IBM Cloud Console](https://cloud.ibm.com)
2. Click on **Manage** in the top navigation bar
3. Select **Access (IAM)** from the dropdown
4. Click on **API keys** in the left sidebar

> **Navigation Path:** `Manage > Access (IAM) > API keys`

### 2. Create a New API Key

1. Click the **"Create an IBM Cloud API key"** button
2. In the dialog that appears, enter a descriptive name:
   ```
   watsonx-api-key-yourname
   ```
3. Optionally add a description (e.g., "API key for Network Management MVP ai-core service")
4. Click **Create**

### 3. Save Your API Key

> **CRITICAL:** Copy and save the API key immediately! You won't be able to see it again after closing the dialog.

1. When the API key is generated, click **Copy** or manually select and copy the entire key
2. Store it securely in a password manager or secure note
3. You'll use this key in the next step to configure the `.env` file

> **Security Best Practice:** Never commit API keys to version control. Always use environment variables or secure secret management systems.

---

## Step 3: Configure the ai-core .env File

Now that you have your API key, it's time to configure the ai-core service.

### 1. Locate the ai-core Directory

Navigate to the ai-core service directory in your project:

```bash
cd ibm-live-project-intern/ai-core
```

### 2. Create the .env File

If a `.env` file doesn't already exist, create one:

```bash
touch .env
```

Or copy from the example template (if provided):

```bash
cp .env.example .env
```

### 3. Configure Environment Variables

Open the `.env` file in your text editor and add the following configuration:

```bash
# IBM Watsonx AI Configuration
# API Key from IBM Cloud (IAM)
WATSONX_API_KEY=your_api_key_here

# Watsonx API URL (default for watsonx.ai)
WATSONX_URL=https://us-south.ml.cloud.ibm.com

# IBM Cloud Project ID (optional, can be obtained from watsonx.ai console)
WATSONX_PROJECT_ID=your_project_id_here

# Model Configuration
# Recommended models: ibm/granite-13b-chat-v2, meta-llama/llama-2-70b-chat
WATSONX_MODEL=ibm/granite-13b-chat-v2

# Service Configuration
PORT=9000
LOG_LEVEL=info

# API Gateway Integration (optional)
API_GATEWAY_URL=http://localhost:8080
```

### 4. Fill in Required Values

| Variable | Description | Required |
|----------|-------------|----------|
| `WATSONX_API_KEY` | The API key you created in Step 2 | Yes |
| `WATSONX_URL` | Watsonx API endpoint (use default shown above) | Yes |
| `WATSONX_PROJECT_ID` | Project ID from watsonx.ai console (optional for basic usage) | Optional |
| `WATSONX_MODEL` | AI model to use (default: granite-13b-chat-v2) | Yes |
| `PORT` | Port for ai-core service (default: 9000) | Yes |

> **Getting Project ID (Optional):**
> 1. Go to [watsonx.ai](https://watsonx.ai)
> 2. Create or select a project
> 3. The Project ID appears in the project settings or URL

### 5. Verify Configuration

Your final `.env` file should look something like this (with your actual values):

```bash
WATSONX_API_KEY=ibmcloud_api_AbCdEfGhIjKlMnOpQrStUvWxYz1234567890
WATSONX_URL=https://us-south.ml.cloud.ibm.com
WATSONX_PROJECT_ID=abc123-def456-ghi789
WATSONX_MODEL=ibm/granite-13b-chat-v2
PORT=9000
LOG_LEVEL=info
API_GATEWAY_URL=http://localhost:8080
```

> **Configuration Complete!** Your ai-core service is now ready to use IBM Watsonx AI for intelligent alert analysis.

---

## Step 4: Test Your Configuration

### 1. Start the ai-core Service

Test that your configuration works by starting the service:

```bash
# From the ai-core directory
go run main.go

# Or if using Docker:
docker compose up ai-core
```

### 2. Check the Logs

Look for successful initialization messages:

```
INFO: Watsonx client initialized successfully
INFO: Using model: ibm/granite-13b-chat-v2
INFO: AI Core service listening on :9000
```

> **Common Errors:**
> - **401 Unauthorized:** Check your API key is correct
> - **Connection refused:** Verify WATSONX_URL is correct
> - **Model not found:** Ensure the model name is valid

### 3. Test Alert Analysis (Optional)

If the api-gateway is running, test the full integration:

```bash
curl -X POST http://localhost:8080/api/alerts/analyze \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "alert_id": 1,
    "message": "High CPU usage detected on server prod-01",
    "severity": "critical"
  }'
```

> **Success!** If you receive an AI-generated analysis response, your Watsonx integration is working correctly!

---

## Additional Resources

- [IBM Cloud Documentation](https://cloud.ibm.com/docs)
- [IBM Watsonx.ai Documentation](https://www.ibm.com/docs/en/watsonx-as-a-service)
- [IBM Academic Initiative Documentation](https://github.com/academic-initiative/documentation)
- [Available Foundation Models in Watsonx](https://dataplatform.cloud.ibm.com/docs/content/wsj/analyze-data/fm-models.html)

---

## Security Best Practices

- Never commit `.env` files to version control (ensure `.env` is in `.gitignore`)
- Never share API keys in chat messages, screenshots, or public forums
- Rotate API keys periodically (every 90 days recommended)
- Use different API keys for development and production environments
- Delete unused API keys from IBM Cloud IAM
- Store credentials in secure secret management systems in production

> **If Your API Key is Exposed:**
> 1. Immediately delete the compromised key in IBM Cloud IAM
> 2. Generate a new API key
> 3. Update your `.env` file with the new key
> 4. Review recent activity logs in IBM Cloud

---

## Complete Environment Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `WATSONX_API_KEY` | string | *required* | IBM Cloud API key with Watsonx access |
| `WATSONX_URL` | string | `https://us-south.ml.cloud.ibm.com` | Watsonx API endpoint URL |
| `WATSONX_PROJECT_ID` | string | *optional* | Watsonx project identifier |
| `WATSONX_MODEL` | string | `ibm/granite-13b-chat-v2` | Foundation model to use for analysis |
| `PORT` | integer | `9000` | Port for ai-core service to listen on |
| `LOG_LEVEL` | string | `info` | Logging level (debug, info, warn, error) |
| `API_GATEWAY_URL` | string | `http://localhost:8080` | URL of the api-gateway service |
