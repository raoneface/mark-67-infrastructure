#!/bin/bash
set -e

# Function to cleanup on exit
cleanup() {
    echo "Shutting down..."
    jobs -p | xargs -r kill 2>/dev/null || true
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup SIGINT SIGTERM EXIT

echo "Todo Application Deployment Script"
echo ""
echo "Choose deployment option:"
echo "1. Docker Deployment (Local)"
echo "2. AWS Infrastructure (Terraform + Puppet)"
echo "3. Development Setup (Local)"
echo "4. Test Deployment"
echo "5. Configure Puppet (Sign Certificates & Test Agents)"
echo "6. Deploy Todo App via Puppet (Frontend + Backend)"
echo "7. Verify Deployment Status"
echo "8. Setup GitHub Secrets for CI/CD"
echo ""
read -p "Enter your choice (1-8): " choice

case $choice in
    1)
        echo "Starting Docker Deployment..."
        
        # Create logs directory
        mkdir -p logs
        
        # Stop any existing containers
        echo "Stopping existing containers..."
        docker-compose down --volumes 2>/dev/null || true
        docker container prune -f 2>/dev/null || true
        
        # Start the application
        echo "Building and starting Todo Application..."
        docker-compose up --build -d
        
        # Wait for services to start
        echo "Waiting for services to start..."
        sleep 30
        
        # Run tests
        echo "Running deployment tests..."
        if [ -f "test-docker-deployment.sh" ]; then
            ./test-docker-deployment.sh
        else
            echo "Checking services manually..."
            
            # Check backend health
            if curl -s http://localhost:8080/actuator/health > /dev/null; then
                echo "✓ Backend is healthy"
            else
                echo "✗ Backend health check failed"
            fi
            
            # Check frontend
            if curl -s -I http://localhost:3000 > /dev/null; then
                echo "✓ Frontend is accessible"
            else
                echo "✗ Frontend is not accessible"
            fi
        fi
        
        echo ""
        echo "Docker deployment completed successfully!"
        echo "Frontend: http://localhost:3000"
        echo "Backend API: http://localhost:8080/api/todos"
        echo "Health Check: http://localhost:8080/actuator/health"
        echo "MongoDB: localhost:27017"
        echo "Logs: ./logs/"
        echo ""
        echo "Press Ctrl+C to stop all services..."
        
        # Show logs
        docker-compose logs -f
        ;;
    2)
        echo "Starting AWS Infrastructure Deployment..."
        
        # Check if we're in the right directory
        if [ ! -d "terraform" ]; then
            echo "Error: Terraform directory not found!"
            exit 1
        fi
        
        cd terraform
        
        # Setup Terraform Backend if not exists
        if [ ! -f "backend.tf" ]; then
            echo "Setting up Terraform Backend (S3 + DynamoDB)..."
            
            # Configuration
            BUCKET_NAME="terraform-state-$(date +%s)-$(whoami)"
            DYNAMODB_TABLE="terraform-state-lock"
            AWS_REGION="us-east-1"

            echo "S3 Bucket: $BUCKET_NAME"
            echo "DynamoDB Table: $DYNAMODB_TABLE"
            echo "Region: $AWS_REGION"

            # Check AWS CLI
            if ! command -v aws &> /dev/null; then
                echo "Error: AWS CLI is not installed."
                exit 1
            fi

            if ! aws sts get-caller-identity &> /dev/null; then
                echo "Error: AWS credentials not configured. Run 'aws configure' first."
                exit 1
            fi

            echo "AWS CLI is configured"

            # Create S3 bucket
            echo "Creating S3 bucket for Terraform state..."
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$AWS_REGION" \
                --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null || \
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$AWS_REGION" 2>/dev/null

            # Enable versioning
            aws s3api put-bucket-versioning \
                --bucket "$BUCKET_NAME" \
                --versioning-configuration Status=Enabled

            # Enable encryption
            aws s3api put-bucket-encryption \
                --bucket "$BUCKET_NAME" \
                --server-side-encryption-configuration '{
                    "Rules": [
                        {
                            "ApplyServerSideEncryptionByDefault": {
                                "SSEAlgorithm": "AES256"
                            }
                        }
                    ]
                }'

            # Block public access
            aws s3api put-public-access-block \
                --bucket "$BUCKET_NAME" \
                --public-access-block-configuration \
                BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

            # Create DynamoDB table
            echo "Creating DynamoDB table for state locking..."
            aws dynamodb create-table \
                --table-name "$DYNAMODB_TABLE" \
                --attribute-definitions AttributeName=LockID,AttributeType=S \
                --key-schema AttributeName=LockID,KeyType=HASH \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region "$AWS_REGION" || echo "Table might already exist"

            # Wait for table
            aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"

            # Create backend configuration
            cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "puppet-infrastructure/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$DYNAMODB_TABLE"
    encrypt        = true
  }
}
EOF

            echo "Terraform backend setup completed!"
        else
            echo "Backend already configured"
        fi
        
        # Check terraform.tfvars
        if [ ! -f "terraform.tfvars" ]; then
            echo "Error: terraform.tfvars not found!"
            echo "Copy terraform.tfvars.example to terraform.tfvars and update with your values."
            exit 1
        fi

        # Deploy infrastructure
        echo "Initializing Terraform..."
        terraform init

        echo "Validating Terraform configuration..."
        terraform validate

        echo "Planning Terraform deployment..."
        terraform plan

        echo "Auto-applying Terraform plan..."

        echo "Applying Terraform configuration..."
        terraform apply -auto-approve

        echo ""
        echo "Puppet Infrastructure deployment completed!"
        echo ""
        echo "Next Steps:"
        echo "1. Wait 5-10 minutes for instances to complete setup"
        echo "2. SSH to Puppet Master and sign agent certificates"
        echo "3. On Puppet Master: sudo /opt/puppetlabs/bin/puppetserver ca sign --all"
        echo "4. Test agents: sudo /opt/puppetlabs/bin/puppet agent --test"
        echo ""
        terraform output
        ;;
    3)
        echo "Starting Development Setup..."
        
        # Create logs directory
        mkdir -p logs
        
        # Check MongoDB
        if ! docker ps | grep -q mongo; then
            echo "Starting MongoDB..."
            cd demo
            docker-compose up -d mongodb
            cd ..
            sleep 10
        else
            echo "MongoDB is already running"
        fi
        
        # Start backend
        echo "Starting Spring Boot backend..."
        cd demo
        ./mvnw spring-boot:run > ../logs/backend-dev.log 2>&1 &
        BACKEND_PID=$!
        cd ..
        
        # Wait for backend
        echo "Waiting for backend to start..."
        sleep 20
        
        # Check backend
        if curl -s http://localhost:8080/actuator/health > /dev/null; then
            echo "✓ Backend is running"
        else
            echo "✗ Backend failed to start. Check logs/backend-dev.log"
            kill $BACKEND_PID 2>/dev/null || true
            exit 1
        fi
        
        # Start frontend
        echo "Starting Next.js frontend..."
        cd ui
        npm run dev > ../logs/frontend-dev.log 2>&1 &
        FRONTEND_PID=$!
        cd ..
        
        # Wait for frontend
        echo "Waiting for frontend to start..."
        sleep 15
        
        # Check frontend
        if curl -s -I http://localhost:3000 > /dev/null; then
            echo "✓ Frontend is running"
        else
            echo "✗ Frontend failed to start. Check logs/frontend-dev.log"
            kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
            exit 1
        fi
        
        echo ""
        echo "Development environment is ready!"
        echo "Frontend: http://localhost:3000"
        echo "Backend API: http://localhost:8080/api/todos"
        echo "Health Check: http://localhost:8080/actuator/health"
        echo "Backend Logs: logs/backend-dev.log"
        echo "Frontend Logs: logs/frontend-dev.log"
        echo ""
        echo "Press Ctrl+C to stop all services..."
        
        # Keep running
        wait
        ;;
    4)
        echo "Running Deployment Tests..."
        
        # Check if Docker deployment is running
        if docker ps | grep -q "todo-"; then
            echo "Testing Docker deployment..."
            if [ -f "test-docker-deployment.sh" ]; then
                ./test-docker-deployment.sh
            else
                echo "Error: Test script not found!"
                exit 1
            fi
        else
            echo "Error: No Docker containers running. Start deployment first."
            exit 1
        fi
        ;;
    5)
        echo "Configuring Puppet Infrastructure..."
        
        # Check if terraform directory exists and has outputs
        if [ ! -d "terraform" ]; then
            echo "Error: Terraform directory not found!"
            exit 1
        fi
        
        cd terraform
        
        # Get Terraform outputs
        echo "Getting infrastructure details..."
        PUPPET_MASTER_IP=$(terraform output -raw puppet_master_public_ip 2>/dev/null)
        FRONTEND_IP=$(terraform output -raw app_frontend_public_ip 2>/dev/null)
        BACKEND_IP=$(terraform output -raw app_backend_public_ip 2>/dev/null)
        
        if [ -z "$PUPPET_MASTER_IP" ] || [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ]; then
            echo "Error: Could not get infrastructure IPs. Make sure Terraform deployment is complete."
            exit 1
        fi
        
        echo "Infrastructure IPs:"
        echo "  Puppet Master: $PUPPET_MASTER_IP"
        echo "  Frontend: $FRONTEND_IP"
        echo "  Backend: $BACKEND_IP"
        
        # Check if PEM file exists
        PEM_FILE="../project-mark-67.pem"
        if [ ! -f "$PEM_FILE" ]; then
            echo "Error: PEM file not found at $PEM_FILE"
            exit 1
        fi
        
        # Set proper permissions for PEM file
        chmod 400 "$PEM_FILE"
        
        echo ""
        echo "Step 1: Waiting for instances to complete setup..."
        echo "Waiting 1 min for Puppet services to install and start..."
        echo "This includes system updates, Java installation, and Puppet setup..."
        sleep 60
        
        echo ""
        echo "Step 2: Checking Puppet Master status..."
        echo "Checking if Puppet Master installation completed..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$PUPPET_MASTER_IP \
            "export PATH='/opt/puppetlabs/bin:$PATH'; sudo systemctl status puppetserver --no-pager" || echo "Puppet Master may still be starting..."
        
        echo "Checking Puppet Master setup log..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$PUPPET_MASTER_IP \
            "tail -20 /var/log/puppet-master-setup.log" || echo "Setup log not available yet..."
        
        echo ""
        echo "Step 3: Listing pending certificates..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$PUPPET_MASTER_IP \
            "sudo /opt/puppetlabs/bin/puppetserver ca list --all" || echo "No certificates yet or Puppet Master not ready..."
        
        echo ""
        echo "Step 4: Signing all certificates..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$PUPPET_MASTER_IP \
            "sudo /opt/puppetlabs/bin/puppetserver ca sign --all" || echo "No certificates to sign yet or Puppet Master not ready..."
        
        echo ""
        echo "Step 5: Testing Puppet agents..."
        
        echo "Testing Frontend agent..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test" || echo "Frontend agent test completed with warnings (normal for first run)"
        
        echo ""
        echo "Testing Backend agent..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test" || echo "Backend agent test completed with warnings (normal for first run)"
        
        echo ""
        echo "Step 6: Final certificate signing (for any new certificates)..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$PUPPET_MASTER_IP \
            "sudo /opt/puppetlabs/bin/puppetserver ca sign --all"
        
        echo ""
        echo "Step 7: Final agent tests..."
        echo "Running final test on Frontend..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test"
        
        echo ""
        echo "Running final test on Backend..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test"
        
        echo ""
        echo "Step 8: Verifying Puppet managed files..."
        echo "Checking if Puppet created managed files on agents..."
        
        echo "Frontend managed files:"
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "ls -la /tmp/puppet-managed /tmp/frontend-node 2>/dev/null || echo 'Managed files not created yet'"
        
        echo "Backend managed files:"
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "ls -la /tmp/puppet-managed /tmp/backend-node 2>/dev/null || echo 'Managed files not created yet'"
        
        echo ""
        echo "Puppet configuration completed!"
        echo ""
        echo "Infrastructure Summary:"
        echo "  Puppet Master: $PUPPET_MASTER_IP"
        echo "  Frontend Agent: $FRONTEND_IP"
        echo "  Backend Agent: $BACKEND_IP"
        echo ""
        echo "SSH Commands:"
        echo "  ssh -i $PEM_FILE ubuntu@$PUPPET_MASTER_IP"
        echo "  ssh -i $PEM_FILE ubuntu@$FRONTEND_IP"
        echo "  ssh -i $PEM_FILE ubuntu@$BACKEND_IP"
        echo ""
        echo "Service URLs:"
        echo "  Puppet Master Console: https://$PUPPET_MASTER_IP:8140"
        echo "  Frontend App: http://$FRONTEND_IP:3000"
        echo "  Backend App: http://$BACKEND_IP:8080"
        echo ""
        echo "Troubleshooting:"
        echo "  Check setup logs: tail -f /var/log/puppet-*-setup.log"
        echo "  Manual certificate signing: sudo puppetserver ca sign --all"
        echo "  Manual agent run: sudo puppet agent --test"
        
        cd ..
        ;;
    6)
        echo "Deploying Todo Application via Puppet..."
        
        # Check if terraform directory exists and has outputs
        if [ ! -d "terraform" ]; then
            echo "Error: Terraform directory not found!"
            exit 1
        fi
        
        cd terraform
        
        # Get Terraform outputs
        echo "Getting infrastructure details..."
        PUPPET_MASTER_IP=$(terraform output -raw puppet_master_public_ip 2>/dev/null)
        FRONTEND_IP=$(terraform output -raw app_frontend_public_ip 2>/dev/null)
        BACKEND_IP=$(terraform output -raw app_backend_public_ip 2>/dev/null)
        
        if [ -z "$PUPPET_MASTER_IP" ] || [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ]; then
            echo "Error: Could not get infrastructure IPs. Make sure Terraform deployment is complete."
            exit 1
        fi
        
        echo "Infrastructure IPs:"
        echo "  Puppet Master: $PUPPET_MASTER_IP"
        echo "  Frontend: $FRONTEND_IP"
        echo "  Backend: $BACKEND_IP"
        
        # Check if PEM file exists
        PEM_FILE="../project-mark-67.pem"
        if [ ! -f "$PEM_FILE" ]; then
            echo "Error: PEM file not found at $PEM_FILE"
            exit 1
        fi
        
        # Set proper permissions for PEM file
        chmod 400 "$PEM_FILE"
        
        echo ""
        echo "Step 1: Deploying Puppet manifests for Todo App..."
        
        # Copy deployment manifests to Puppet Master
        echo "Copying deployment manifests to Puppet Master..."
        scp -i "$PEM_FILE" -o StrictHostKeyChecking=no -r scripts/puppet-deploy-manifests/* ubuntu@$PUPPET_MASTER_IP:/tmp/
        
        # Install manifests on Puppet Master
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$PUPPET_MASTER_IP << 'EOF'
            # Copy manifests to Puppet directory
            sudo cp /tmp/site.pp /etc/puppetlabs/code/environments/production/manifests/
            
            # Create modules directory if it doesn't exist
            sudo mkdir -p /etc/puppetlabs/code/environments/production/modules
            
            # Set proper ownership
            sudo chown -R puppet:puppet /etc/puppetlabs/code/environments/production/
            
            echo "Puppet manifests installed successfully"
EOF
        
        echo ""
        echo "Step 2: Setting up Docker Hub credentials..."
        
        # Prompt for Docker Hub credentials
        read -p "Enter your Docker Hub username: " DOCKERHUB_USERNAME
        read -s -p "Enter your Docker Hub password/token: " DOCKERHUB_PASSWORD
        echo ""
        
        # Set up Docker Hub credentials on both agents
        echo "Setting up Docker Hub credentials on Frontend..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP << EOF
            # Login to Docker Hub
            echo "$DOCKERHUB_PASSWORD" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
            
            # Create environment file
            sudo mkdir -p /opt/todo-app/frontend
            echo "DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME" | sudo tee /opt/todo-app/frontend/.env
            echo "BACKEND_IP=$BACKEND_IP" | sudo tee -a /opt/todo-app/frontend/.env
            
            echo "Frontend Docker Hub setup complete"
EOF
        
        echo "Setting up Docker Hub credentials on Backend..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP << EOF
            # Login to Docker Hub
            echo "$DOCKERHUB_PASSWORD" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
            
            # Create environment file
            sudo mkdir -p /opt/todo-app/backend
            echo "DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME" | sudo tee /opt/todo-app/backend/.env
            
            echo "Backend Docker Hub setup complete"
EOF
        
        echo ""
        echo "Step 3: Running Puppet agent to deploy applications..."
        
        # Run Puppet agent on Frontend
        echo "Deploying Frontend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test" || echo "Frontend deployment completed (warnings are normal)"
        
        # Run Puppet agent on Backend
        echo "Deploying Backend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test" || echo "Backend deployment completed (warnings are normal)"
        
        echo ""
        echo "Step 4: Starting applications manually (first time)..."
        
        # Start Frontend application
        echo "Starting Frontend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP << EOF
            cd /opt/todo-app/frontend
            
            # Update docker-compose.yml with actual values
            sed -i "s/\\\${DOCKERHUB_USERNAME}/$DOCKERHUB_USERNAME/g" docker-compose.yml
            sed -i "s/\\\${BACKEND_IP}/$BACKEND_IP/g" docker-compose.yml
            
            # Pull and start containers
            docker compose pull
            docker compose up -d
            
            echo "Frontend containers started"
EOF
        
        # Start Backend application
        echo "Starting Backend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP << EOF
            cd /opt/todo-app/backend
            
            # Update docker-compose.yml with actual values
            sed -i "s/\\\${DOCKERHUB_USERNAME}/$DOCKERHUB_USERNAME/g" docker-compose.yml
            
            # Pull and start containers
            docker compose pull
            docker compose up -d
            
            echo "Backend containers started"
EOF
        
        echo ""
        echo "Step 5: Verifying deployments..."
        
        # Wait for services to start
        echo "Waiting for services to start..."
        sleep 30
        
        # Check Frontend
        echo "Checking Frontend service..."
        if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP "curl -f http://localhost:3000" > /dev/null 2>&1; then
            echo "✅ Frontend is running successfully"
        else
            echo "⚠️  Frontend may still be starting up"
        fi
        
        # Check Backend
        echo "Checking Backend service..."
        if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP "curl -f http://localhost:8080/actuator/health" > /dev/null 2>&1; then
            echo "✅ Backend is running successfully"
        else
            echo "⚠️  Backend may still be starting up"
        fi
        
        echo ""
        echo "🎉 Todo Application Deployment via Puppet Completed!"
        echo ""
        echo "Application URLs:"
        echo "  Frontend: http://$FRONTEND_IP:3000"
        echo "  Backend API: http://$BACKEND_IP:8080/api/todos"
        echo "  Backend Health: http://$BACKEND_IP:8080/actuator/health"
        echo ""
        echo "SSH Commands:"
        echo "  Frontend: ssh -i $PEM_FILE ubuntu@$FRONTEND_IP"
        echo "  Backend: ssh -i $PEM_FILE ubuntu@$BACKEND_IP"
        echo ""
        echo "Puppet Auto-Deployment:"
        echo "  ✅ Cron jobs set up to pull new images every 5 minutes"
        echo "  ✅ Push new images to Docker Hub and they'll auto-deploy"
        echo ""
        echo "Logs:"
        echo "  Frontend Deploy: ssh -i $PEM_FILE ubuntu@$FRONTEND_IP 'tail -f /var/log/frontend-deploy.log'"
        echo "  Backend Deploy: ssh -i $PEM_FILE ubuntu@$BACKEND_IP 'tail -f /var/log/backend-deploy.log'"
        
        cd ..
        ;;
    7)
        echo "🔍 Verifying Todo Application Deployment Status..."
        echo "=================================================="
        
        # Check if terraform directory exists
        if [ ! -d "terraform" ]; then
            echo "❌ Terraform directory not found!"
            exit 1
        fi
        
        # Get IPs from Terraform
        cd terraform
        FRONTEND_IP=$(terraform output -raw app_frontend_public_ip 2>/dev/null)
        BACKEND_IP=$(terraform output -raw app_backend_public_ip 2>/dev/null)
        PUPPET_MASTER_IP=$(terraform output -raw puppet_master_public_ip 2>/dev/null)
        cd ..
        
        if [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ]; then
            echo "❌ Could not get EC2 IPs from Terraform"
            echo "Make sure infrastructure is deployed first (option 2)"
            exit 1
        fi
        
        echo "Infrastructure:"
        echo "  Puppet Master: $PUPPET_MASTER_IP"
        echo "  Frontend: $FRONTEND_IP"
        echo "  Backend: $BACKEND_IP"
        echo ""
        
        # Test Frontend
        echo "🌐 Testing Frontend..."
        if curl -s -f "http://$FRONTEND_IP:3000" > /dev/null; then
            echo "✅ Frontend is accessible at http://$FRONTEND_IP:3000"
        else
            echo "❌ Frontend is not accessible at http://$FRONTEND_IP:3000"
        fi
        
        # Test Backend Health
        echo "🔧 Testing Backend Health..."
        if curl -s -f "http://$BACKEND_IP:8080/actuator/health" > /dev/null; then
            echo "✅ Backend health check passed at http://$BACKEND_IP:8080/actuator/health"
        else
            echo "❌ Backend health check failed at http://$BACKEND_IP:8080/actuator/health"
        fi
        
        # Test Backend API
        echo "📡 Testing Backend API..."
        if curl -s -f "http://$BACKEND_IP:8080/api/todos" > /dev/null; then
            echo "✅ Backend API is accessible at http://$BACKEND_IP:8080/api/todos"
        else
            echo "❌ Backend API is not accessible at http://$BACKEND_IP:8080/api/todos"
        fi
        
        # Test Database Connection
        echo "🗄️  Testing Database Connection..."
        HEALTH_RESPONSE=$(curl -s "http://$BACKEND_IP:8080/actuator/health" 2>/dev/null || echo "")
        if echo "$HEALTH_RESPONSE" | grep -q "UP"; then
            echo "✅ Database connection is healthy"
        else
            echo "❌ Database connection issues detected"
        fi
        
        echo ""
        echo "🔗 Application URLs:"
        echo "  Frontend: http://$FRONTEND_IP:3000"
        echo "  Backend API: http://$BACKEND_IP:8080/api/todos"
        echo "  Health Check: http://$BACKEND_IP:8080/actuator/health"
        echo "  Puppet Master: https://$PUPPET_MASTER_IP:8140"
        echo ""
        
        # Check Docker containers on EC2s
        echo "🐳 Checking Docker Containers..."
        PEM_FILE="project-mark-67.pem"
        
        if [ -f "$PEM_FILE" ]; then
            chmod 400 "$PEM_FILE"
            
            echo "Frontend containers:"
            ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$FRONTEND_IP \
                "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "  Could not connect to frontend EC2"
            
            echo ""
            echo "Backend containers:"
            ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$BACKEND_IP \
                "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "  Could not connect to backend EC2"
            
            echo ""
            echo "Puppet Master status:"
            ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUPPET_MASTER_IP \
                "sudo systemctl is-active puppetserver" 2>/dev/null || echo "  Could not connect to Puppet Master"
        else
            echo "⚠️  PEM file not found at $PEM_FILE, skipping container check"
        fi
        
        echo ""
        echo "✅ Verification completed!"
        ;;
    8)
        echo "🔧 Setting up GitHub Secrets for CI/CD Pipeline..."
        echo "================================================="
        echo ""
        
        # Check if GitHub CLI is installed
        if ! command -v gh &> /dev/null; then
            echo "❌ GitHub CLI (gh) is not installed."
            echo ""
            echo "Install options:"
            echo "  macOS: brew install gh"
            echo "  Ubuntu: sudo apt install gh"
            echo "  Or visit: https://cli.github.com/"
            echo ""
            echo "Alternative: Add secrets manually via GitHub web interface"
            echo "Repository → Settings → Secrets and variables → Actions"
            exit 1
        fi
        
        # Check if user is logged in to GitHub
        if ! gh auth status &> /dev/null; then
            echo "🔐 Please login to GitHub CLI first:"
            echo "gh auth login"
            echo ""
            echo "Then run this script again."
            exit 1
        fi
        
        echo "✅ GitHub CLI is ready!"
        echo ""
        
        # Get repository info
        REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [ -z "$REPO" ]; then
            echo "❌ Not in a GitHub repository or repository not found."
            echo "Make sure you're in a Git repository with GitHub remote."
            exit 1
        fi
        
        echo "📁 Repository: $REPO"
        echo ""
        
        # Function to set secret
        set_secret() {
            local name=$1
            local value=$2
            
            if [ -z "$value" ]; then
                echo "⚠️  Skipping $name (empty value)"
                return
            fi
            
            echo "Setting $name..."
            echo "$value" | gh secret set "$name"
            echo "✅ $name set successfully"
        }
        
        # Docker Hub credentials
        echo "🐳 Docker Hub Setup"
        echo "==================="
        echo "You need a Docker Hub account and access token for CI/CD."
        echo ""
        read -p "Enter your Docker Hub username: " DOCKERHUB_USERNAME
        
        if [ -z "$DOCKERHUB_USERNAME" ]; then
            echo "❌ Docker Hub username is required!"
            exit 1
        fi
        
        echo ""
        echo "Docker Hub Token Setup:"
        echo "1. Go to https://hub.docker.com/"
        echo "2. Login → Account Settings → Security"
        echo "3. Click 'New Access Token'"
        echo "4. Name: 'github-actions'"
        echo "5. Permissions: 'Read, Write, Delete'"
        echo ""
        read -s -p "Enter your Docker Hub token: " DOCKERHUB_TOKEN
        echo ""
        
        if [ -z "$DOCKERHUB_TOKEN" ]; then
            echo "❌ Docker Hub token is required!"
            exit 1
        fi
        
        # AWS credentials
        echo ""
        echo "☁️  AWS Credentials Setup"
        echo "========================"
        echo "These are needed to access Terraform state and get EC2 IPs dynamically."
        echo ""
        
        # Try to get AWS credentials from current session
        AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
        AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
        AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
        
        if [ -n "$AWS_ACCESS_KEY_ID" ]; then
            echo "Found existing AWS credentials in your AWS CLI config."
            read -p "Use existing AWS credentials? (y/n): " use_existing
            if [ "$use_existing" != "y" ]; then
                AWS_ACCESS_KEY_ID=""
                AWS_SECRET_ACCESS_KEY=""
            fi
        fi
        
        if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            echo "Enter your AWS credentials (same as used for Terraform):"
            read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
            read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
            echo ""
            read -p "AWS Region (default: us-east-1): " input_region
            AWS_REGION=${input_region:-us-east-1}
        fi
        
        if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            echo "❌ AWS credentials are required!"
            exit 1
        fi
        
        # SSH Key
        echo ""
        echo "🔑 SSH Key Setup"
        echo "==============="
        PEM_FILE="project-mark-67.pem"
        
        if [ -f "$PEM_FILE" ]; then
            echo "Found PEM file: $PEM_FILE"
            EC2_SSH_KEY=$(cat "$PEM_FILE")
        else
            echo "PEM file not found at $PEM_FILE"
            read -p "Enter path to your PEM file: " pem_path
            if [ -f "$pem_path" ]; then
                EC2_SSH_KEY=$(cat "$pem_path")
            else
                echo "❌ PEM file not found at $pem_path"
                exit 1
            fi
        fi
        
        # Set all secrets
        echo ""
        echo "🚀 Setting GitHub Secrets..."
        echo "============================"
        
        set_secret "DOCKERHUB_USERNAME" "$DOCKERHUB_USERNAME"
        set_secret "DOCKERHUB_TOKEN" "$DOCKERHUB_TOKEN"
        set_secret "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
        set_secret "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
        set_secret "AWS_REGION" "$AWS_REGION"
        set_secret "EC2_SSH_KEY" "$EC2_SSH_KEY"
        
        echo ""
        echo "🎉 All secrets have been set successfully!"
        echo ""
        echo "📋 Summary:"
        echo "  ✅ DOCKERHUB_USERNAME"
        echo "  ✅ DOCKERHUB_TOKEN"
        echo "  ✅ AWS_ACCESS_KEY_ID"
        echo "  ✅ AWS_SECRET_ACCESS_KEY"
        echo "  ✅ AWS_REGION"
        echo "  ✅ EC2_SSH_KEY"
        echo ""
        echo "🚀 Your CI/CD pipeline is now ready!"
        echo ""
        echo "Next steps:"
        echo "1. Push your code to GitHub:"
        echo "   git add ."
        echo "   git commit -m 'Setup CI/CD pipeline'"
        echo "   git push origin main"
        echo ""
        echo "2. Monitor deployments at:"
        echo "   https://github.com/$REPO/actions"
        echo ""
        echo "3. The pipeline will automatically:"
        echo "   - Build Docker images when you push code"
        echo "   - Deploy to your EC2 instances"
        echo "   - Skip builds if images already exist"
        echo "   - Get EC2 IPs dynamically from Terraform"
        ;;
    *)
        echo "Error: Invalid choice. Please select 1-8."
        exit 1
        ;;
esac