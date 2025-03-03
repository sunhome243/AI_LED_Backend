# User Auth Table with uuid as hash key and pin as range key
# Only for prototype / MVP
resource "aws_dynamodb_table" "user-auth-table" {
    name           = "AuthTable"
    billing_mode   = "ON_DEMAND"
    hash_key = "uuid" # partition key
    range_key = "pin" # sort key

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
    billing_mode   = "ON_DEMAND"
    hash_key = "deviceType" # partition key
    range_key = "id" # sort key

    attribute {
        name = "deviceType"
        type = "S"
    }

    attribute {
        name = "id"
        type = "N"
    }

    attribute {
        name = "irCode"
        type = "S"
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

resource "aws_dynamodb_table" "websocket-connectionid-table" {
    name           = "ConnectionIdTable"
    billing_mode   = "ON_DEMAND"
    hash_key = "uuid" # partition key
    range_key = "connectionId" # sort key

    attribute {
        name = "uuid"
        type = "S"
    }

    attribute {
        name = "connectionId"
        type = "N"
    }

    ttl {
        attribute_name = "TimeToExist"
        enabled        = false
    }

    tags = {
        Name        = "ConnectionIdTable"
        Environment = "dev"
        Type = "Sensitive"
    }
}


resource "aws_dynamodb_table" "response-table" {
    name           = "ResponseTable"
    billing_mode   = "ON_DEMAND"
    hash_key       = "uuid" # partition key
    range_key      = "DAY#TIME" # optimized sort key

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