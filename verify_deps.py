import sys
import pkg_resources
import os

# Add the layer directory to path if it exists
if os.path.exists("./layer/python"):
    sys.path.append("./layer/python")

# Core required packages for the application
required_packages = [
    "boto3", "shortuuid", "google-genai", "httpx",
    "typing-extensions", "anyio", "google-auth",
    "google-api-core", "protobuf", "aiohttp"
]

# Additional packages that might be required based on imports
additional_packages = [
    "exceptiongroup", "multidict", "yarl", "frozenlist",
    "attrs", "async-timeout", "aiosignal", "requests"
]

print("\n=== Checking core dependencies ===")
missing_core = []
for package in required_packages:
    try:
        pkg_resources.get_distribution(package)
        print(f"✓ {package} is installed")
    except pkg_resources.DistributionNotFound:
        missing_core.append(package)
        print(f"✗ {package} is MISSING")

print("\n=== Checking additional dependencies ===")
missing_additional = []
for package in additional_packages:
    try:
        pkg_resources.get_distribution(package)
        print(f"✓ {package} is installed")
    except pkg_resources.DistributionNotFound:
        missing_additional.append(package)
        print(f"✗ {package} is MISSING")

# Write out missing packages
if missing_core or missing_additional:
    with open("./missing_deps.txt", "w") as f:
        if missing_core:
            f.write("=== Missing Core Packages ===\n")
            f.write("\n".join(missing_core))
            f.write("\n\n")
        if missing_additional:
            f.write("=== Missing Additional Packages ===\n")
            f.write("\n".join(missing_additional))

    print(
        f"\nMissing {len(missing_core)} core packages and {len(missing_additional)} additional packages.")
    print("See missing_deps.txt for details")
    sys.exit(1)
else:
    print("\nAll required packages verified!")
    sys.exit(0)
