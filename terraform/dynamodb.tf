# User Auth Table with uuid as hash key and pin as range key
# Only for prototype / MVP
resource "aws_dynamodb_table" "user-auth-table" {
    name           = "AuthTable"
    billing_mode   = "PROVISIONED"
    hash_key = "uuid" # partition key
    range_key = "pin" # sort key

    read_capacity  = 3
    write_capacity = 1

    attribute {
        name = "uuid"
        type = "S"
    }

    attribute {
        name = "pin"
        type = "S"
    }

    ttl {
        attribute_name = "TimeToExist"
        enabled        = false
    }

    tags = {
        Name        = "AuthTable"
        Environment = "dev"
        Type = "HighlySensitive"
    }
}

resource "aws_dynamodb_table" "ircode-transition-table" {
    name           = "IrCodeTable"
    billing_mode   = "PROVISIONED"
    hash_key = "deviceType" # partition key
    range_key = "id" # sort key

    read_capacity  = 5
    write_capacity = 1

    attribute {
        name = "deviceType"
        type = "S"
    }

    attribute {
        name = "id"
        type = "N"
    }

    ttl {
        attribute_name = "TimeToExist"
        enabled        = false
    }

    tags = {
        Name        = "IrCodeTable"
        Environment = "dev"
        Type = "NotSensitive"
    }
}

resource "aws_dynamodb_table" "response-table" {
    name           = "ResponseTable"
    billing_mode   = "PROVISIONED"
    hash_key       = "uuid" # partition key
    range_key      = "DAY#TIME" # optimized sort key

    read_capacity  = 5
    write_capacity = 5

    attribute {
        name = "uuid"
        type = "S"
    }

    attribute {
        name = "DAY#TIME"
        type = "S"
    }

    ttl {
        attribute_name = "TimeToExist"
        enabled        = false
    }

    tags = {
        Name        = "ResponseTable"
        Environment = "dev"
        Type        = "HighlySensitive"
    }
}

resource "aws_dynamodb_table" "connection_table" {
    name           = "ConnectionIdTable"
    billing_mode   = "PROVISIONED"
    hash_key       = "uuid"

    read_capacity  = 5
    write_capacity = 5

    attribute {
    name = "uuid"
    type = "S"
    }

    tags = {
    Name        = "WebSocket Connection Table"
    Environment = "develop"
  }
}