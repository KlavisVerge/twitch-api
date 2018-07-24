terraform {
  backend "local" {
    path = "tf_backend/twitch-api.tfstate"
  }
}

variable "REST_API_ID" {}
variable "PARENT_ID" {}
variable "AWS_ACCESS_KEY" {}
variable "AWS_SECRET_ACCESS_KEY" {}
variable "CLIENT_ID" {}

data "aws_iam_role" "role" {
  name = "apis-for-all-service-account"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "${var.AWS_ACCESS_KEY}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
}

resource "aws_api_gateway_resource" "twitch-api-resource" {
  rest_api_id = "${var.REST_API_ID}"
  parent_id   = "${var.PARENT_ID}"
  path_part   = "twitch-api"
}

resource "aws_api_gateway_resource" "twitch-games-resource" {
  rest_api_id = "${var.REST_API_ID}"
  parent_id   = "${var.PARENT_ID}"
  path_part   = "twitch-games"
}

resource "aws_lambda_function" "twitch-api-function" {
  filename      = "twitch-api.zip"
  function_name = "twitch-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/twitch-api.handler"
  source_code_hash = "${base64sha256(file("twitch-api.zip"))}"
  runtime          = "nodejs6.10"
  timeout          = 20

  environment {
    variables {
      CLIENT_ID = "${var.CLIENT_ID}"
    }
  }
}

resource "aws_lambda_function" "twitch-games-function" {
  filename      = "twitch-api.zip"
  function_name = "twitch-games"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/twitch-games.handler"
  source_code_hash = "${base64sha256(file("twitch-api.zip"))}"
  runtime          = "nodejs6.10"
  timeout          = 20

  environment {
    variables {
      CLIENT_ID = "${var.CLIENT_ID}"
    }
  }
}

resource "aws_lambda_permission" "twitch-permission" {
  function_name = "${aws_lambda_function.twitch-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "twitch-permission-games" {
  function_name = "${aws_lambda_function.twitch-games-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "twitch-api-method-post" {
  rest_api_id   = "${var.REST_API_ID}"
  resource_id   = "${aws_api_gateway_resource.twitch-api-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "twitch-games-method-post" {
  rest_api_id   = "${var.REST_API_ID}"
  resource_id   = "${aws_api_gateway_resource.twitch-games-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "twitch-api-integration" {
  rest_api_id             = "${var.REST_API_ID}"
  resource_id             = "${aws_api_gateway_resource.twitch-api-resource.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.twitch-api-function.invoke_arn}"
}

resource "aws_api_gateway_integration" "twitch-games-integration" {
  rest_api_id             = "${var.REST_API_ID}"
  resource_id             = "${aws_api_gateway_resource.twitch-games-resource.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.twitch-games-function.invoke_arn}"
}

module "CORS_FUNCTION_DETAILS" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.twitch-api-resource.id}"
  rest_api_id = "${var.REST_API_ID}"
}

module "CORS_FUNCTION_DETAILS_GAMES" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.twitch-games-resource.id}"
  rest_api_id = "${var.REST_API_ID}"
}
