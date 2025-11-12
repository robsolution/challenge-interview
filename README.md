# AWS VPC Provisioning API

🎯 Description

This project implements a secure, asynchronous, serverless API on AWS to provision and manage Virtual Private Clouds (VPCs). The solution is built with DevOps best practices, using Infrastructure as Code (IaC) with Terraform and automated deployment with GitHub Actions.

### ✨ Core Features

* **Asynchronous VPC Creation:** Initiate VPC creation with a simple API call and receive a `job_id` to track its progress.
* **Cost-Optimized Architecture:** Creates a complete VPC with public and private subnets, a single NAT Gateway, and shared route tables to reduce costs.
* **Security:** Endpoints are secured with Amazon Cognito for JWT-based authentication and authorization.
* **Automated CI/CD:** A deployment pipeline is configured with GitHub Actions for automatic provisioning on AWS.

## 🏛️ Architecture

The architecture is 100% serverless and event-driven to handle the long-running nature of VPC creation.

1. **Authentication:** `Amazon Cognito` manages users and authentication (JWT).
2. **API Gateway:** Exposes the `POST /vpc` and `GET /vpc/{job_id}` endpoints.
3. **`POST /vpc` Endpoint:**
   * Protected by a Cognito Authorizer.
   * Triggers the `api_handler` Lambda, which validates the input, generates a `job_id`, stores the initial state in DynamoDB, and starts the `Step Function`.
   * Returns `202 Accepted` immediately with the `job_id`.
4. **`GET /vpc/{job_id}` Endpoint:**
   * Also protected.
   * The `api_handler` Lambda queries `DynamoDB` and returns the job's status/result.
5. **Step Function:** Orchestrates the creation workflow, invoking the `vpc_builder` Lambda and managing retries and error handling.
6. **`vpc_builder` Lambda:**
   * Contains the core logic to create the VPC and its components (Subnets, IGW, NAT Gateway, Route Tables) using Boto3.
   * Updates the job status in `DynamoDB` to `RUNNING`, `COMPLETE`, or `FAILED`.
7. **DynamoDB:** Acts as our state database, storing the progress and results of each request.

## Terraform (Infrastructure as Code)

All AWS infrastructure is managed by Terraform, located in the `terraform/` directory.

### File Structure

* `tf_01_backend.tf`: Configures the remote S3 backend to store the state file (`.tfstate`), ensuring a collaborative and secure environment.
* `tf_02_provider.tf`: Defines the AWS provider and region.
* `tf_03_variables.tf`: Declares project input variables, such as `project_name` and `environment`.
* `tf_04_data.tf`: Used to fetch information from the AWS account, like the account ID and current region.
* `tf_05_iam.tf`: Creates the necessary IAM Roles and Policies for the Lambdas and Step Function to access other AWS services.
* `tf_06_lambda.tf`: Defines the Lambda functions (`api_handler` and `vpc_builder`), including their environment variables and source code packaging.
* `tf_07_dynamodb.tf`: Creates the DynamoDB table to store job states.
* `tf_08_api_gateway.tf`: Configures the API Gateway, its resources (`/vpc`, `/vpc/{job_id}`), methods (POST, GET), and integration with the `api_handler` Lambda.
* `tf_09_cognito.tf`: Provisions the Cognito User Pool and App Client for user management and authentication.
* `tf_10_step_function.tf`: Defines the Step Function state machine that orchestrates VPC creation.
* `tf_11_outputs.tf`: Exposes important outputs after deployment, such as the API URL and Cognito App Client ID.

## 🚀 Setup and Deployment (CI/CD)

Deployment is automated via GitHub Actions.

### Prerequisites

1. **AWS Account:** With permissions to create the required resources (IAM, VPC, Lambda, etc.).
2. **Terraform Backend:** Manually create an S3 bucket and a DynamoDB table (for state locking) in your AWS account. Update the `terraform/tf_01_backend.tf` file with the correct bucket name and region.
3. **OIDC in AWS:** Configure OpenID Connect (OIDC) in AWS IAM to allow GitHub Actions to securely assume a Role.
   * Create an IAM Role with the necessary permissions for Terraform.
   * Update the `.github/workflows/deploy.yml` file with your role's ARN in the `role-to-assume` section.

### Deployment

1. Fork and clone this repository.
2. Complete the prerequisites above.
3. Push your changes to the `main` branch. The GitHub Actions workflow will trigger, applying the Terraform configuration and provisioning all infrastructure.

## 🛠️ How to Test the API

After deployment, Terraform will display the API URL and Cognito App Client ID in the `outputs`.

### 1. Create a Test User

Use the AWS CLI to sign up a new user in your Cognito User Pool.

```bash
aws cognito-idp sign-up \
  --client-id YOUR_COGNITO_APP_CLIENT_ID \
  --username your_email@example.com \
  --password "YourStrongPassword@123" \
  --user-attributes Name="email",Value="your_email@example.com"

# You will need to confirm the user in the AWS console (Cognito -> User Pools -> your-pool -> Users)
```

### 2. Get an Authentication Token

Log in with the created user to obtain an `IdToken`.

```bash
aws cognito-idp initiate-auth \
  --client-id YOUR_COGNITO_APP_CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=your_email@example.com,PASSWORD="YourStrongPassword@123"
```

Copy the `IdToken` value from the JSON response.

### 3. Create a VPC (POST /vpc)

Make a `POST` call to the `/vpc` endpoint, passing the `IdToken` in the `Authorization` header.

```bash
# Export variables for convenience
export API_URL="YOUR_API_GATEWAY_INVOKE_URL"
export TOKEN="YOUR_COPIED_ID_TOKEN_HERE"

curl -X POST "$API_URL/vpc" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"cidr": "10.150.0.0/16"}'
```

The expected response is a `202 Accepted` with the `job_id`:

```json
{
  "job_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "status": "PENDING"
}
```

### 4. Check Creation Status (GET /vpc/)

Use the received `job_id` to query the creation status.

```bash
# Export the job_id
export JOB_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

curl -X GET "$API_URL/vpc/$JOB_ID" \
  -H "Authorization: Bearer $TOKEN"
```

* **While in progress:**
  ```json
  {
    "job_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "status": "RUNNING",
    "request_payload": "{\"cidr\": \"10.150.0.0/16\"}"
  }
  ```
* **After completion:**
  ```json
  {
    "job_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "status": "COMPLETE",
    "request_payload": "{\"cidr\": \"10.150.0.0/16\"}",
    "results": "{\"vpc_id\": \"vpc-0...\", \"internet_gateway_id\": \"igw-0...\", ...}"
  }
  ```


<summary>🇧🇷 Ver em Português</summary>

## 🎯 Descrição

Este projeto implementa uma API serverless, segura e assíncrona na AWS para provisionar e gerenciar VPCs (Virtual Private Clouds). A solução é construída com as melhores práticas de DevOps, utilizando Infraestrutura como Código (IaC) com Terraform e implantação automatizada com GitHub Actions.

### ✨ Funcionalidades Principais

* **Criação Assíncrona de VPC:** Inicie a criação de uma VPC com uma simples chamada de API e receba um `job_id` para rastrear o progresso.
* **Arquitetura Otimizada para Custos:** Cria uma VPC completa com sub-redes públicas e privadas, um único NAT Gateway e tabelas de rotas compartilhadas para reduzir custos.
* **Segurança:** Endpoints protegidos com Amazon Cognito para autenticação e autorização baseadas em JWT.
* **CI/CD Automatizado:** Pipeline de deploy configurado com GitHub Actions para provisionamento automático na AWS.

## 🏛️ Arquitetura

A arquitetura é 100% serverless e orientada a eventos para lidar com a natureza de longa duração da criação de VPCs.

1. **Autenticação:** O `Amazon Cognito` gerencia usuários e autenticação (JWT).
2. **API Gateway:** Expõe os endpoints `POST /vpc` e `GET /vpc/{job_id}`.
3. **Endpoint `POST /vpc`:**
   * Protegido por um Autorizador Cognito.
   * Aciona a Lambda `api_handler`, que valida a entrada, gera um `job_id`, armazena o estado inicial no DynamoDB e inicia a `Step Function`.
   * Retorna `202 Accepted` imediatamente com o `job_id`.
4. **Endpoint `GET /vpc/{job_id}`:**
   * Também protegido.
   * A Lambda `api_handler` consulta o `DynamoDB` e retorna o status/resultado do job.
5. **Step Function:** Orquestra o fluxo de criação, invocando a Lambda `vpc_builder` e gerenciando retentativas e captura de erros.
6. **Lambda `vpc_builder`:**
   * Contém a lógica principal para criar a VPC e seus componentes (Subnets, IGW, NAT Gateway, Route Tables) usando o Boto3.
   * Atualiza o status do job no `DynamoDB` para `RUNNING`, `COMPLETE` ou `FAILED`.
7. **DynamoDB:** Atua como banco de dados de estado, armazenando o progresso e os resultados de cada solicitação.

## Terraform (Infraestrutura como Código)

Toda a infraestrutura da AWS é gerenciada pelo Terraform, localizada no diretório `terraform/`.

### Estrutura dos Arquivos

* `tf_01_backend.tf`: Configura o backend remoto do Terraform no S3 para armazenar o arquivo de estado (`.tfstate`), garantindo um ambiente colaborativo e seguro.
* `tf_02_provider.tf`: Define o provedor AWS e a região.
* `tf_03_variables.tf`: Declara as variáveis de entrada do projeto, como `project_name` e `environment`.
* `tf_04_data.tf`: Utilizado para obter informações da conta AWS, como ID da conta e região atual.
* `tf_05_iam.tf`: Cria as IAM Roles e Policies necessárias para que as Lambdas e a Step Function acessem outros serviços da AWS.
* `tf_06_lambda.tf`: Define as funções Lambda (`api_handler` e `vpc_builder`), incluindo suas variáveis de ambiente e o empacotamento do código-fonte.
* `tf_07_dynamodb.tf`: Cria a tabela do DynamoDB para armazenar o estado dos jobs.
* `tf_08_api_gateway.tf`: Configura o API Gateway, seus recursos (`/vpc`, `/vpc/{job_id}`), métodos (POST, GET) e a integração com a Lambda `api_handler`.
* `tf_09_cognito.tf`: Provisiona o User Pool e o App Client do Cognito para gerenciamento de usuários e autenticação.
* `tf_10_step_function.tf`: Define a máquina de estados da Step Function que orquestra a criação da VPC.
* `tf_11_outputs.tf`: Expõe saídas importantes após o deploy, como a URL da API e o ID do Cognito App Client.

## 🚀 Setup e Implantação (CI/CD)

A implantação é automatizada via GitHub Actions.

### Pré-requisitos

1. **Conta AWS:** Com permissões para criar os recursos (IAM, VPC, Lambda, etc.).
2. **Backend do Terraform:** Crie manualmente um bucket S3 e uma tabela DynamoDB (para lock de estado) na sua conta AWS. Atualize o arquivo `terraform/tf_01_backend.tf` com os nomes corretos do bucket e da região.
3. **OIDC na AWS:** Configure o OpenID Connect (OIDC) no IAM da AWS para permitir que o GitHub Actions assuma uma Role de forma segura.
   * Crie uma IAM Role com as permissões necessárias para o Terraform.
   * Atualize o arquivo `.github/workflows/deploy.yml` com o ARN da sua role na seção `role-to-assume`.

### Implantação

1. Faça um fork e clone este repositório.
2. Execute os pré-requisitos acima.
3. Faça o push das suas alterações para a branch `main`. O workflow do GitHub Actions será acionado, aplicando o Terraform e provisionando toda a infraestrutura.

## 🛠️ Como Testar a API

Após a implantação, o Terraform exibirá a URL da API e o ID do Cognito App Client nos `outputs`.

### 1. Crie um Usuário de Teste

Use a AWS CLI para registrar um novo usuário no seu Cognito User Pool.

```bash
aws cognito-idp sign-up \
  --client-id SEU_COGNITO_APP_CLIENT_ID \
  --username seu_email@exemplo.com \
  --password "SuaSenhaForte@123" \
  --user-attributes Name="email",Value="seu_email@exemplo.com"

# Você precisará confirmar o usuário no console da AWS (Cognito -> User Pools -> seu-pool -> Users)
```

### 2. Obtenha um Token de Autenticação

Faça login com o usuário criado para obter um `IdToken`.

```bash
aws cognito-idp initiate-auth \
  --client-id SEU_COGNITO_APP_CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=seu_email@exemplo.com,PASSWORD="SuaSenhaForte@123"
```

Copie o valor do `IdToken` da resposta JSON.

### 3. Crie uma VPC (POST /vpc)

Faça uma chamada `POST` para o endpoint `/vpc`, passando o `IdToken` no cabeçalho `Authorization`.

```bash
# Exporte as variáveis para facilitar
export API_URL="SUA_API_GATEWAY_INVOKE_URL"
export TOKEN="SEU_ID_TOKEN_COPIADO_AQUI"

curl -X POST "$API_URL/vpc" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"cidr": "10.150.0.0/16"}'
```

A resposta esperada é um `202 Accepted` com o `job_id`:

```json
{
  "job_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "status": "PENDING"
}
```

### 4. Verifique o Status da Criação (GET /vpc/)

Use o `job_id` recebido para consultar o status da criação.

```bash
# Exporte o job_id
export JOB_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

curl -X GET "$API_URL/vpc/$JOB_ID" \
  -H "Authorization: Bearer $TOKEN"
```

* **Enquanto estiver em andamento:**
  ```json
  {
    "job_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "status": "RUNNING",
    "request_payload": "{\"cidr\": \"10.150.0.0/16\"}"
  }
  ```
* **Após a conclusão:**
  ```json
  {
    "job_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "status": "COMPLETE",
    "request_payload": "{\"cidr\": \"10.150.0.0/16\"}",
    "results": "{\"vpc_id\": \"vpc-0...\", \"internet_gateway_id\": \"igw-0...\", ...}"
  }
  ```

</details>

*
