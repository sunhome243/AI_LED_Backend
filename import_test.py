import sys
import os
sys.path.insert(0, "./layer/python")

# Print the contents of the python directory for debugging
print("=== Contents of layer/python directory ===")
for item in os.listdir("./layer/python"):
    if os.path.isdir("./layer/python/" + item):
        print(f"Dir: {item}")
    else:
        print(f"File: {item}")

# If google directory exists, show its contents
google_dir = "./layer/python/google"
if os.path.isdir(google_dir):
    print("\n=== Contents of google directory ===")
    for item in os.listdir(google_dir):
        if os.path.isdir(google_dir + "/" + item):
            print(f"Dir: {item}")
        else:
            print(f"File: {item}")

modules_to_test = [
    "boto3", "shortuuid", "google", "exceptiongroup", 
    "typing_extensions", "anyio", "httpx", "multidict", "aiohttp",
    "aiosignal", "attrs", "requests"
]

print("\n=== Testing basic imports ===")
missing = []
for module in modules_to_test:
    try:
        __import__(module)
        print(f"✓ {module} imported successfully")
    except ImportError as e:
        missing.append(f"{module}: {str(e)}")
        print(f"✗ Error importing {module}: {e}")

# Specifically test google.generativeai
print("\n=== Testing google.generativeai import ===")
try:
    # Try different import approaches
    try:
        import google.generativeai
        print("✓ google.generativeai imported successfully")
    except ImportError:
        # Try with direct import of google_generativeai package
        import google_generativeai
        print("✓ google_generativeai imported successfully (alternative name)")
    except ImportError:
        # Last resort: see if any genai modules exist
        found = False
        for path in sys.path:
            if os.path.exists(os.path.join(path, "google/generativeai")):
                found = True
                print(f"✓ google/generativeai directory exists at {path}")
                break
            if os.path.exists(os.path.join(path, "genai")):
                found = True
                print(f"✓ genai directory exists at {path}")
                break
        
        if not found:
            print("✗ Could not find google.generativeai or related modules")
            missing.append("google.generativeai: Module not found in path")
except Exception as e:
    missing.append(f"google.generativeai error: {str(e)}")
    print(f"✗ Error with google.generativeai: {e}")

if missing:
    print("\nMISSING MODULES:")
    for m in missing:
        print(f"  - {m}")
    sys.exit(1)
else:
    print("\nAll modules imported successfully!")
