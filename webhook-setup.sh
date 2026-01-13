#!/bin/bash

# GitHub Webhook Setup Script
# This script provides instructions for setting up a GitHub webhook

echo "================================================"
echo "GitHub Webhook Setup Instructions"
echo "================================================"
echo ""
echo "To enable automatic Jenkins builds on git push, follow these steps:"
echo ""
echo "1. Go to your GitHub repository"
echo "2. Navigate to Settings > Webhooks > Add webhook"
echo "3. Configure the webhook:"
echo "   - Payload URL: http://YOUR_JENKINS_URL/github-webhook/"
echo "   - Content type: application/json"
echo "   - Secret: (optional, but recommended)"
echo "   - SSL verification: Enable if using HTTPS"
echo "   - Events: Select 'Just the push event'"
echo ""
echo "4. In Jenkins, configure your job:"
echo "   - Go to job configuration"
echo "   - Under 'Build Triggers', enable:"
echo "     ☑ GitHub hook trigger for GITScm polling"
echo ""
echo "5. Save both configurations"
echo ""
echo "================================================"
echo "Testing the Webhook"
echo "================================================"
echo ""
echo "After setup, push a commit to test:"
echo "  git add ."
echo "  git commit -m 'Test webhook trigger'"
echo "  git push origin main"
echo ""
echo "Check Jenkins to verify the build was triggered automatically."
echo ""
echo "================================================"
echo "Webhook Payload Example"
echo "================================================"
echo ""

cat << 'EOF'
{
  "ref": "refs/heads/main",
  "before": "abc123...",
  "after": "def456...",
  "repository": {
    "name": "weather-monitoring",
    "full_name": "username/weather-monitoring",
    "url": "https://github.com/username/weather-monitoring"
  },
  "pusher": {
    "name": "username",
    "email": "user@example.com"
  },
  "commits": [
    {
      "id": "def456...",
      "message": "Update weather monitor",
      "timestamp": "2024-01-13T12:00:00Z",
      "author": {
        "name": "username",
        "email": "user@example.com"
      }
    }
  ]
}
EOF

echo ""
echo "================================================"
echo "Jenkins Pipeline Configuration"
echo "================================================"
echo ""
echo "Ensure your Jenkinsfile includes:"
echo "  - SCM polling configuration"
echo "  - GitHub repository URL"
echo "  - Credentials for GitHub access"
echo ""
echo "The Jenkinsfile in this project is already configured"
echo "to work with GitHub webhooks."
echo ""
