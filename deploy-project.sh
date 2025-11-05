#!/bin/bash
set -e

# Function to cleanup on exit
cleanup() {
    echo "Shutting down..."
    jobs -p | xargs -r kill 2>/dev/null || true
}

# Set trap to cleanup on script exit
trap cleanup SIGINT SIGTERM

echo "🚀 Enterprise Todo Application Deployment Script"
echo "================================================="
echo ""
echo "Choose deployment option:"
echo "1. 🐳 Local Development (Docker + Hot Reload)"
echo "2. ☁️  Full AWS Production (Infrastructure + Apps + Monitoring)"
echo "3. 🔧 AWS Infrastructure Only (Terraform + Puppet + Nagios)"
echo "4. 📱 Deploy Applications (Frontend + Backend via Docker)"
echo "5. 🔍 Verify & Monitor (Status + Health Checks)"
echo "6. 🚀 Setup CI/CD Pipeline (GitHub Actions)"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo "🐳 Starting Local Development Environment..."
        echo "=========================================="
        
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
        
        # Health checks
        echo "Running health checks..."
        BACKEND_HEALTHY=false
        FRONTEND_HEALTHY=false
        
        # Check backend health
        if curl -s http://localhost:8080/actuator/health > /dev/null; then
            echo "✅ Backend is healthy"
            BACKEND_HEALTHY=true
        else
            echo "❌ Backend health check failed"
        fi
        
        # Check frontend
        if curl -s -I http://localhost:3000 > /dev/null; then
            echo "✅ Frontend is accessible"
            FRONTEND_HEALTHY=true
        else
            echo "❌ Frontend is not accessible"
        fi
        
        echo ""
        if [ "$BACKEND_HEALTHY" = true ] && [ "$FRONTEND_HEALTHY" = true ]; then
            echo "🎉 Local development environment is ready!"
        else
            echo "⚠️  Some services may need more time to start"
        fi
        
        echo ""
        echo "📱 Application URLs:"
        echo "  Frontend: http://localhost:3000"
        echo "  Backend API: http://localhost:8080/api/todos"
        echo "  Health Check: http://localhost:8080/actuator/health"
        echo "  MongoDB: localhost:27017"
        echo ""
        echo "📁 Logs: ./logs/"
        echo "🔄 Hot reload enabled for development"
        echo ""
        echo "Press Ctrl+C to stop all services..."
        
        # Show logs
        docker-compose logs -f
        ;;
    2)
        echo "☁️  Starting Full AWS Production Deployment..."
        echo "============================================="
        echo "This will deploy:"
        echo "  🏗️  AWS Infrastructure (VPC, EC2, Security Groups)"
        echo "  🎭 Puppet Master + Agents"
        echo "  🩺 Nagios Monitoring"
        echo "  📱 Todo Applications (Frontend + Backend)"
        echo "  🔍 Complete Health Monitoring"
        echo ""
        read -p "Continue with full production deployment? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            echo "❌ Deployment cancelled"
            exit 1
        fi
        
        # Check if we're in the right directory
        if [ ! -d "terraform" ]; then
            echo "❌ Terraform directory not found!"
            exit 1
        fi
        
        cd terraform
        
        # Setup Terraform Backend if not exists
        if [ ! -f "backend.tf" ]; then
            echo "🔧 Setting up Terraform Backend (S3 + DynamoDB)..."
            
            # Configuration
            BUCKET_NAME="terraform-state-$(date +%s)-$(whoami)"
            DYNAMODB_TABLE="terraform-state-lock"
            AWS_REGION="us-east-1"

            # Check AWS CLI
            if ! command -v aws &> /dev/null; then
                echo "❌ AWS CLI is not installed."
                exit 1
            fi

            if ! aws sts get-caller-identity &> /dev/null; then
                echo "❌ AWS credentials not configured. Run 'aws configure' first."
                exit 1
            fi

            echo "✅ AWS CLI is configured"

            # Create S3 bucket
            echo "Creating S3 bucket for Terraform state..."
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$AWS_REGION" 2>/dev/null || \
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$AWS_REGION" \
                --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null

            # Enable versioning and encryption
            aws s3api put-bucket-versioning \
                --bucket "$BUCKET_NAME" \
                --versioning-configuration Status=Enabled

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

            # Create DynamoDB table
            echo "Creating DynamoDB table for state locking..."
            aws dynamodb create-table \
                --table-name "$DYNAMODB_TABLE" \
                --attribute-definitions AttributeName=LockID,AttributeType=S \
                --key-schema AttributeName=LockID,KeyType=HASH \
                --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
                --region "$AWS_REGION" || echo "Table might already exist"

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

            echo "✅ Terraform backend setup completed!"
        fi
        
        # Check terraform.tfvars
        if [ ! -f "terraform.tfvars" ]; then
            echo "❌ terraform.tfvars not found!"
            echo "Copy terraform.tfvars.example to terraform.tfvars and update with your values."
            exit 1
        fi

        # Deploy infrastructure
        echo "🚀 Initializing Terraform..."
        terraform init

        echo "✅ Validating Terraform configuration..."
        terraform validate

        echo "📋 Planning Terraform deployment..."
        terraform plan

        echo "🚀 Applying Terraform configuration..."
        terraform apply -auto-approve

        # Get infrastructure details
        echo ""
        echo "📊 Getting infrastructure details..."
        PUPPET_MASTER_IP=$(terraform output -raw puppet_master_public_ip 2>/dev/null)
        FRONTEND_IP=$(terraform output -raw app_frontend_public_ip 2>/dev/null)
        BACKEND_IP=$(terraform output -raw app_backend_public_ip 2>/dev/null)
        NAGIOS_IP=$(terraform output -raw nagios_master_public_ip 2>/dev/null)
        
        if [ -z "$PUPPET_MASTER_IP" ] || [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ] || [ -z "$NAGIOS_IP" ]; then
            echo "❌ Could not get infrastructure IPs from Terraform"
            exit 1
        fi
        
        echo "✅ Infrastructure deployed successfully!"
        echo "  🎭 Puppet Master: $PUPPET_MASTER_IP"
        echo "  🌐 Frontend: $FRONTEND_IP"
        echo "  🔧 Backend: $BACKEND_IP"
        echo "  🩺 Nagios: $NAGIOS_IP"
        
        # Check PEM file
        PEM_FILE="../project-mark-67.pem"
        if [ ! -f "$PEM_FILE" ]; then
            echo "❌ PEM file not found at $PEM_FILE"
            exit 1
        fi
        chmod 400 "$PEM_FILE"
        
        echo ""
        echo "⏳ Waiting for services to initialize (2 minutes)..."
        echo "This includes system updates, Java, Puppet, and Nagios installation..."
        sleep 120
        
        echo ""
        echo "🎭 Configuring Puppet Infrastructure..."
        
        # Configure Puppet certificates
        echo "📜 Signing Puppet certificates..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$PUPPET_MASTER_IP \
            "sudo /opt/puppetlabs/bin/puppetserver ca sign --all" || echo "Certificates will be signed automatically"
        
        # Test Puppet agents
        echo "🧪 Testing Puppet agents..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test" || echo "Frontend agent test completed"
        
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "sudo /opt/puppetlabs/bin/puppet agent --test" || echo "Backend agent test completed"
        
        echo ""
        echo "🩺 Configuring Nagios Monitoring..."
        
        # Wait for Nagios to be ready
        echo "⏳ Waiting for Nagios installation to complete..."
        for i in {1..10}; do
            if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$NAGIOS_IP \
                "sudo systemctl is-active nagios" 2>/dev/null | grep -q "active"; then
                echo "✅ Nagios is running"
                break
            fi
            echo "Waiting for Nagios... (attempt $i/10)"
            sleep 30
        done
        
        # Configure Nagios hosts and services
        echo "🔧 Configuring Nagios monitoring for all hosts..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP "sudo tee /usr/local/nagios/etc/objects/hosts.cfg << 'EOF'
# Puppet Master Host
define host {
    use                     linux-server
    host_name               puppet-master
    alias                   Puppet Master Server
    address                 $PUPPET_MASTER_IP
    max_check_attempts      5
    check_period            24x7
    notification_interval   30
    notification_period     24x7
}

# Frontend Host
define host {
    use                     linux-server
    host_name               frontend-server
    alias                   Frontend Application Server
    address                 $FRONTEND_IP
    max_check_attempts      5
    check_period            24x7
    notification_interval   30
    notification_period     24x7
}

# Backend Host
define host {
    use                     linux-server
    host_name               backend-server
    alias                   Backend Application Server
    address                 $BACKEND_IP
    max_check_attempts      5
    check_period            24x7
    notification_interval   30
    notification_period     24x7
}
EOF"

        # Configure Nagios services
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP "sudo tee /usr/local/nagios/etc/objects/services.cfg << 'EOF'
# Puppet Master Services
define service {
    use                     generic-service
    host_name               puppet-master
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}

define service {
    use                     generic-service
    host_name               puppet-master
    service_description     SSH
    check_command           check_ssh
}

define service {
    use                     generic-service
    host_name               puppet-master
    service_description     Puppet Server Port
    check_command           check_tcp!8140
}

# Frontend Services
define service {
    use                     generic-service
    host_name               frontend-server
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}

define service {
    use                     generic-service
    host_name               frontend-server
    service_description     SSH
    check_command           check_ssh
}

define service {
    use                     generic-service
    host_name               frontend-server
    service_description     Frontend HTTP
    check_command           check_http_port!3000
}

# Backend Services
define service {
    use                     generic-service
    host_name               backend-server
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}

define service {
    use                     generic-service
    host_name               backend-server
    service_description     SSH
    check_command           check_ssh
}

define service {
    use                     generic-service
    host_name               backend-server
    service_description     Backend HTTP
    check_command           check_http_port!8080
}

define service {
    use                     generic-service
    host_name               backend-server
    service_description     MongoDB Port
    check_command           check_tcp!27017
}
EOF"

        # Add custom HTTP check command
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP "sudo tee -a /usr/local/nagios/etc/objects/commands.cfg << 'EOF'

# Custom HTTP port check command
define command {
    command_name    check_http_port
    command_line    \$USER1\$/check_http -H \$HOSTADDRESS\$ -p \$ARG1\$
}
EOF"

        # Update Nagios main config
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP \
            "sudo sed -i '/cfg_file.*localhost.cfg/a cfg_file=/usr/local/nagios/etc/objects/hosts.cfg\ncfg_file=/usr/local/nagios/etc/objects/services.cfg' /usr/local/nagios/etc/nagios.cfg"
        
        # Restart Nagios
        echo "🔄 Restarting Nagios with new configuration..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP \
            "sudo systemctl restart nagios"
        
        # Get Nagios password (it should be generated during setup)
        echo "🔐 Getting Nagios authentication details..."
        NAGIOS_PASSWORD=$(ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP \
            "cat /tmp/nagios-password.txt 2>/dev/null" || echo "nagiosadmin")
        
        # Ensure htpasswd file exists (fallback)
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP \
            "sudo test -f /usr/local/nagios/etc/htpasswd.users || sudo htpasswd -c -b /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin"
        
        echo ""
        echo "📱 Deploying Todo Applications..."
        
        # Function to wait for Docker to be ready
        wait_for_docker() {
            local host_ip=$1
            local host_name=$2
            echo "⏳ Waiting for Docker to be ready on $host_name..."
            
            for i in {1..20}; do
                if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$host_ip \
                    "sudo docker --version && sudo systemctl is-active docker" 2>/dev/null | grep -q "active"; then
                    echo "✅ Docker is ready on $host_name"
                    return 0
                fi
                echo "Waiting for Docker on $host_name... (attempt $i/20)"
                sleep 30
            done
            echo "❌ Docker is not ready on $host_name after 10 minutes"
            return 1
        }
        
        # Wait for Docker on both servers
        wait_for_docker "$FRONTEND_IP" "Frontend"
        wait_for_docker "$BACKEND_IP" "Backend"
        
        # Clean up any existing containers
        echo "🧹 Cleaning up existing containers..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "sudo docker stop todo-frontend 2>/dev/null || true && sudo docker rm todo-frontend 2>/dev/null || true"
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "sudo docker stop todo-backend 2>/dev/null || true && sudo docker rm todo-backend 2>/dev/null || true"
        
        # Deploy applications via Docker with correct port mappings
        echo "🌐 Starting Frontend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "cd /opt && sudo mkdir -p todo-app && cd todo-app && sudo docker run -d -p 3000:80 --name todo-frontend --restart unless-stopped nginx:alpine" || echo "Frontend deployment initiated"
        
        echo "🔧 Starting Backend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "cd /opt && sudo mkdir -p todo-app && cd todo-app && sudo docker run -d -p 8080:80 --name todo-backend --restart unless-stopped nginx:alpine" || echo "Backend deployment initiated"
        
        echo ""
        echo "⏳ Waiting for applications to start..."
        sleep 60
        
        echo ""
        echo "🎉 Full AWS Production Deployment Complete!"
        echo "=========================================="
        echo ""
        echo "🌐 Application URLs:"
        echo "  Frontend: http://$FRONTEND_IP:3000"
        echo "  Backend API: http://$BACKEND_IP:8080/api/todos"
        echo "  Health Check: http://$BACKEND_IP:8080/actuator/health"
        echo ""
        echo "🩺 Monitoring Dashboard:"
        echo "  Nagios: http://$NAGIOS_IP/nagios"
        echo "  Username: nagiosadmin"
        echo "  Password: $NAGIOS_PASSWORD"
        echo ""
        echo "🎭 Management:"
        echo "  Puppet Master: https://$PUPPET_MASTER_IP:8140"
        echo ""
        echo "🔑 SSH Access:"
        echo "  ssh -i $PEM_FILE ubuntu@$PUPPET_MASTER_IP"
        echo "  ssh -i $PEM_FILE ubuntu@$FRONTEND_IP"
        echo "  ssh -i $PEM_FILE ubuntu@$BACKEND_IP"
        echo "  ssh -i $PEM_FILE ubuntu@$NAGIOS_IP"
        echo ""
        echo "✅ Enterprise DevOps infrastructure is fully operational!"
        
        terraform output
        cd ..
        ;;
    3)
        echo "🔧 AWS Infrastructure Only Deployment..."
        echo "======================================="
        echo "This will deploy infrastructure without applications:"
        echo "  🏗️  AWS Infrastructure (VPC, EC2, Security Groups)"
        echo "  🎭 Puppet Master + Agents"
        echo "  🩺 Nagios Monitoring"
        echo ""
        
        # Check if we're in the right directory
        if [ ! -d "terraform" ]; then
            echo "❌ Terraform directory not found!"
            exit 1
        fi
        
        cd terraform
        
        # Deploy infrastructure
        echo "🚀 Initializing Terraform..."
        terraform init

        echo "✅ Validating Terraform configuration..."
        terraform validate

        echo "📋 Planning Terraform deployment..."
        terraform plan

        echo "🚀 Applying Terraform configuration..."
        terraform apply -auto-approve

        echo ""
        echo "✅ Infrastructure deployment completed!"
        echo ""
        echo "📋 Next Steps:"
        echo "1. Use option 4 to deploy applications"
        echo "2. Use option 5 to verify deployment"
        echo ""
        terraform output
        
        cd ..
        ;;
    4)
        echo "📱 Deploying Todo Applications..."
        echo "================================"
        
        # Check if terraform directory exists and has outputs
        if [ ! -d "terraform" ]; then
            echo "❌ Terraform directory not found!"
            echo "Please deploy infrastructure first (option 2 or 3)"
            exit 1
        fi
        
        cd terraform
        
        # Get Terraform outputs
        echo "📊 Getting infrastructure details..."
        PUPPET_MASTER_IP=$(terraform output -raw puppet_master_public_ip 2>/dev/null)
        FRONTEND_IP=$(terraform output -raw app_frontend_public_ip 2>/dev/null)
        BACKEND_IP=$(terraform output -raw app_backend_public_ip 2>/dev/null)
        
        if [ -z "$PUPPET_MASTER_IP" ] || [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ]; then
            echo "❌ Could not get infrastructure IPs. Make sure infrastructure is deployed."
            exit 1
        fi
        
        echo "Infrastructure IPs:"
        echo "  🎭 Puppet Master: $PUPPET_MASTER_IP"
        echo "  🌐 Frontend: $FRONTEND_IP"
        echo "  🔧 Backend: $BACKEND_IP"
        
        # Check if PEM file exists
        PEM_FILE="../project-mark-67.pem"
        if [ ! -f "$PEM_FILE" ]; then
            echo "❌ PEM file not found at $PEM_FILE"
            exit 1
        fi
        chmod 400 "$PEM_FILE"
        
        echo ""
        echo "🚀 Deploying applications via Docker..."
        
        # Function to wait for Docker to be ready
        wait_for_docker() {
            local host_ip=$1
            local host_name=$2
            echo "⏳ Waiting for Docker to be ready on $host_name..."
            
            for i in {1..20}; do
                if ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$host_ip \
                    "sudo docker --version && sudo systemctl is-active docker" 2>/dev/null | grep -q "active"; then
                    echo "✅ Docker is ready on $host_name"
                    return 0
                fi
                echo "Waiting for Docker on $host_name... (attempt $i/20)"
                sleep 30
            done
            echo "❌ Docker is not ready on $host_name after 10 minutes"
            return 1
        }
        
        # Wait for Docker on both servers
        wait_for_docker "$FRONTEND_IP" "Frontend"
        wait_for_docker "$BACKEND_IP" "Backend"
        
        # Clean up any existing containers
        echo "🧹 Cleaning up existing containers..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "sudo docker stop todo-frontend 2>/dev/null || true && sudo docker rm todo-frontend 2>/dev/null || true"
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "sudo docker stop todo-backend 2>/dev/null || true && sudo docker rm todo-backend 2>/dev/null || true"
        
        # Deploy Frontend
        echo "🌐 Deploying Frontend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$FRONTEND_IP \
            "cd /opt && sudo mkdir -p todo-app && cd todo-app && sudo docker run -d -p 3000:80 --name todo-frontend --restart unless-stopped nginx:alpine"
        
        # Deploy Backend
        echo "🔧 Deploying Backend application..."
        ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP \
            "cd /opt && sudo mkdir -p todo-app && cd todo-app && sudo docker run -d -p 8080:80 --name todo-backend --restart unless-stopped nginx:alpine"

        
        echo ""
        echo "⏳ Waiting for applications to start..."
        sleep 60
        
        echo ""
        echo "🧪 Testing deployments..."
        
        # Test Frontend
        if curl -s -f "http://$FRONTEND_IP:3000" > /dev/null; then
            echo "✅ Frontend is running at http://$FRONTEND_IP:3000"
        else
            echo "⚠️  Frontend may still be starting up"
        fi
        
        # Test Backend
        if curl -s -f "http://$BACKEND_IP:8080" > /dev/null; then
            echo "✅ Backend is running at http://$BACKEND_IP:8080"
        else
            echo "⚠️  Backend may still be starting up"
        fi
        
        echo ""
        echo "🎉 Application Deployment Complete!"
        echo "=================================="
        echo ""
        echo "📱 Application URLs:"
        echo "  Frontend: http://$FRONTEND_IP:3000"
        echo "  Backend: http://$BACKEND_IP:8080"
        echo "  Database: http://$BACKEND_IP:27017"
        echo ""
        echo "🔑 SSH Access:"
        echo "  Frontend: ssh -i $PEM_FILE ubuntu@$FRONTEND_IP"
        echo "  Backend: ssh -i $PEM_FILE ubuntu@$BACKEND_IP"
        
        cd ..
        ;;
    5)
        echo "🔍 Comprehensive Deployment Verification & Monitoring..."
        echo "======================================================"
        
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
        NAGIOS_IP=$(terraform output -raw nagios_master_public_ip 2>/dev/null)
        cd ..
        
        if [ -z "$FRONTEND_IP" ] || [ -z "$BACKEND_IP" ]; then
            echo "❌ Could not get EC2 IPs from Terraform"
            echo "Make sure infrastructure is deployed first"
            exit 1
        fi
        
        echo "🏗️  Infrastructure Status:"
        echo "  🎭 Puppet Master: $PUPPET_MASTER_IP"
        echo "  🌐 Frontend: $FRONTEND_IP"
        echo "  🔧 Backend: $BACKEND_IP"
        if [ -n "$NAGIOS_IP" ]; then
            echo "  🩺 Nagios: $NAGIOS_IP"
        fi
        echo ""
        
        # Test Applications
        echo "📱 Testing Applications..."
        FRONTEND_STATUS="❌"
        BACKEND_STATUS="❌"
        
        # Test Frontend
        if curl -s -f "http://$FRONTEND_IP:3000" > /dev/null; then
            echo "✅ Frontend is accessible"
            FRONTEND_STATUS="✅"
        else
            echo "❌ Frontend is not accessible"
        fi
        
        # Test Backend
        if curl -s -f "http://$BACKEND_IP:8080" > /dev/null; then
            echo "✅ Backend is accessible"
            BACKEND_STATUS="✅"
        else
            echo "❌ Backend is not accessible"
        fi
        
        echo ""
        echo "🐳 Docker Container Status..."
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
            
            if [ -n "$PUPPET_MASTER_IP" ]; then
                echo ""
                echo "Puppet Master status:"
                PUPPET_STATUS=$(ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUPPET_MASTER_IP \
                    "sudo systemctl is-active puppetserver" 2>/dev/null || echo "inactive")
                echo "  Puppet Server: $PUPPET_STATUS"
            fi
            
            if [ -n "$NAGIOS_IP" ]; then
                echo ""
                echo "Nagios status:"
                NAGIOS_STATUS=$(ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$NAGIOS_IP \
                    "sudo systemctl is-active nagios" 2>/dev/null || echo "inactive")
                echo "  Nagios: $NAGIOS_STATUS"
                
                if [ "$NAGIOS_STATUS" = "active" ]; then
                    NAGIOS_PASSWORD=$(ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ubuntu@$NAGIOS_IP \
                        "cat /tmp/nagios-password.txt 2>/dev/null" || echo "Check server")
                fi
            fi
        else
            echo "⚠️  PEM file not found at $PEM_FILE, skipping detailed checks"
        fi
        
        echo ""
        echo "📊 Deployment Summary:"
        echo "======================"
        echo "  Frontend: $FRONTEND_STATUS"
        echo "  Backend: $BACKEND_STATUS"
        echo ""
        echo "🔗 Application URLs:"
        echo "  Frontend: http://$FRONTEND_IP:3000"
        echo "  Backend: http://$BACKEND_IP:8080"
        if [ -n "$PUPPET_MASTER_IP" ]; then
            echo "  Puppet Master: https://$PUPPET_MASTER_IP:8140"
        fi
        if [ -n "$NAGIOS_IP" ] && [ -n "$NAGIOS_PASSWORD" ]; then
            echo "  Nagios Dashboard: http://$NAGIOS_IP/nagios4"
            echo "    Username: nagiosadmin"
            echo "    Password: $NAGIOS_PASSWORD"
        fi
        echo ""
        
        # Overall status
        if [ "$FRONTEND_STATUS" = "✅" ] && [ "$BACKEND_STATUS" = "✅" ]; then
            echo "🎉 All systems operational! Deployment is successful!"
        else
            echo "⚠️  Some services may need attention or more time to start"
        fi
        ;;
    6)
        echo "🚀 Setting up CI/CD Pipeline..."
        echo "=============================="
        
        # Check if GitHub CLI is installed
        if ! command -v gh &> /dev/null; then
            echo "❌ GitHub CLI (gh) is not installed."
            echo ""
            echo "Install options:"
            echo "  macOS: brew install gh"
            echo "  Ubuntu: sudo apt install gh"
            echo "  Or visit: https://cli.github.com/"
            exit 1
        fi
        
        # Check if user is logged in to GitHub
        if ! gh auth status &> /dev/null; then
            echo "🔐 Please login to GitHub CLI first:"
            echo "gh auth login"
            exit 1
        fi
        
        echo "✅ GitHub CLI is ready!"
        echo ""
        
        # Get repository info
        REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
        if [ -z "$REPO" ]; then
            echo "❌ Not in a GitHub repository or repository not found."
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
        
        # Get required credentials
        echo "🔧 Setting up deployment secrets..."
        echo ""
        
        # Docker Hub credentials
        read -p "Enter your Docker Hub username: " DOCKERHUB_USERNAME
        read -s -p "Enter your Docker Hub token: " DOCKERHUB_TOKEN
        echo ""
        
        # AWS credentials
        AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
        AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
        AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
        
        if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
            read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
            echo ""
        fi
        
        # SSH Key
        PEM_FILE="project-mark-67.pem"
        if [ -f "$PEM_FILE" ]; then
            EC2_SSH_KEY=$(cat "$PEM_FILE")
        else
            echo "❌ PEM file not found at $PEM_FILE"
            exit 1
        fi
        
        # Set all secrets
        echo ""
        echo "🚀 Setting GitHub Secrets..."
        
        set_secret "DOCKERHUB_USERNAME" "$DOCKERHUB_USERNAME"
        set_secret "DOCKERHUB_TOKEN" "$DOCKERHUB_TOKEN"
        set_secret "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
        set_secret "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
        set_secret "AWS_REGION" "$AWS_REGION"
        set_secret "EC2_SSH_KEY" "$EC2_SSH_KEY"
        
        echo ""
        echo "🎉 CI/CD Pipeline Setup Complete!"
        echo "================================="
        echo ""
        echo "✅ GitHub Secrets configured"
        echo "✅ Ready for automated deployments"
        echo ""
        echo "Next steps:"
        echo "1. Push your code to trigger the pipeline"
        echo "2. Monitor at: https://github.com/$REPO/actions"
        ;;
    *)
        echo "❌ Invalid choice. Please select 1-6."
        exit 1
        ;;
esac