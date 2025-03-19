# AuthTable - Stores user authentication data 
# Hash key: uuid (user identifier)
# Range key: pin (authentication pin)
resource "aws_dynamodb_table" "user-auth-table" {
    name           = "AuthTable"
    billing_mode   = "PROVISIONED"
    hash_key       = "uuid" # partition key
    range_key      = "pin"  # sort key

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

    tags = {
        Name        = "AuthTable"
        Environment = "dev"
        Type        = "HighlySensitive"
    }
}

# IrCodeTable - Stores IR codes for different device types
# Hash key: deviceType (type of device)
# Range key: id (code identifier)
resource "aws_dynamodb_table" "ircode-transition-table" {
    name           = "IrCodeTable"
    billing_mode   = "PROVISIONED"
    hash_key       = "deviceType" # partition key
    range_key      = "id"         # sort key

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

    tags = {
        Name        = "IrCodeTable"
        Environment = "dev"
        Type        = "NotSensitive"
    }
}

# ResponseTable - Stores user response data with time-based organization
# Hash key: uuid (user identifier)
# Range key: TIME#DAY (composite time key for efficient queries)
resource "aws_dynamodb_table" "response-table" {
    name           = "ResponseTable"
    billing_mode   = "PROVISIONED"
    hash_key       = "uuid"      # partition key
    range_key      = "TIME#DAY"  # optimized sort key

    read_capacity  = 5
    write_capacity = 5

    attribute {
        name = "uuid"
        type = "S"
    }

    attribute {
        name = "TIME#DAY"
        type = "S"
    }

    tags = {
        Name        = "ResponseTable"
        Environment = "dev"
        Type        = "HighlySensitive"
    }
}

# ConnectionIdTable - Tracks WebSocket connections
# Hash key: uuid (user identifier)
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
        Environment = "dev"
        Type        = "HighlySensitive"
    }
}