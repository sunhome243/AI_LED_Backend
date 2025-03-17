# Lambda Dependencies Management

## Requirements Files Structure

The project now has a more organized structure for managing Python dependencies:

1. **`requirements.txt`**: The main requirements file that lists all dependencies with specific versions
2. **`lambda-requirements.txt`**: Dependencies specific to AWS Lambda functions

## How to Install Dependencies

### For Local Development

```bash
pip install -r requirements.txt
```

### For Lambda Layer Deployment

```bash
pip install -r lambda-requirements.txt \
    --platform manylinux2014_x86_64 \
    --only-binary=:all: \
    --implementation cp \
    --python-version 3.9 \
    --target ./layer/python \
    --upgrade
```

## Verifying Dependencies

Run the verification script to check if all required packages are installed:

```bash
python verify_deps.py
```

This will check for both core and additional dependencies and report any missing packages.

## Dependency Testing

The `import_test.py` script can be used to test if all modules can be properly imported:

```bash
python import_test.py
```
