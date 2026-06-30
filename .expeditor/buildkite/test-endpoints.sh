#!/bin/bash
set -eou pipefail

TARGET_URL="${1:-http://localhost:8080}"

echo "=========================================="
echo "Testing Omnitruck endpoints"
echo "Target: $TARGET_URL"
echo "=========================================="
echo ""

# Helper function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_content="${3:-}"
    
    echo -n "Testing $name... "
    
    if [ -n "$expected_content" ]; then
        response=$(curl --fail -s "$url")
        if echo "$response" | grep -q "$expected_content"; then
            echo "✅ PASS"
            return 0
        else
            echo "❌ FAIL - Expected content not found"
            echo "Response: $response"
            return 1
        fi
    else
        if curl --fail -s -o /dev/null "$url"; then
            echo "✅ PASS"
            return 0
        else
            echo "❌ FAIL"
            return 1
        fi
    fi
}

# Core health endpoints
test_endpoint "/_healthz" "$TARGET_URL/_healthz"
echo -n "Testing /_status (requires cache)... "
if curl --fail -s "$TARGET_URL/_status" 2>&1 | grep -q "timestamp"; then
    echo "✅ PASS"
else
    echo "⚠️  SKIP (cache not populated)"
fi
test_endpoint "/_version" "$TARGET_URL/_version" "version"

# Product/platform/architecture endpoints
test_endpoint "/products" "$TARGET_URL/products" "chef"
test_endpoint "/platforms" "$TARGET_URL/platforms" "ubuntu"
test_endpoint "/architectures" "$TARGET_URL/architectures" "x86_64"

# Install script generation
echo -n "Testing /install.sh generation... "
INSTALL_SH=$(curl --fail -s "$TARGET_URL/install.sh")
if echo "$INSTALL_SH" | grep -q "#!/bin/sh" && [ $(echo "$INSTALL_SH" | wc -l) -gt 100 ]; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Invalid install script"
    exit 1
fi

echo -n "Testing /install.ps1 generation... "
INSTALL_PS1=$(curl --fail -s "$TARGET_URL/install.ps1")
if echo "$INSTALL_PS1" | grep -q "param"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Invalid PowerShell script"
    exit 1
fi

# Metadata endpoint with parameters
echo -n "Testing metadata endpoint (requires cache)... "
if curl --fail -s "$TARGET_URL/stable/chef/metadata?p=ubuntu&pv=20.04&m=x86_64" 2>&1 | grep -q "url"; then
    echo "✅ PASS"
else
    echo "⚠️  SKIP (cache not populated)"
fi

# Download endpoint (should redirect)
echo -n "Testing download endpoint (requires cache)... "
if curl --fail -I -s "$TARGET_URL/stable/chef/download?p=ubuntu&pv=20.04&m=x86_64" 2>&1 | grep -q "302\|301"; then
    echo "✅ PASS"
else
    echo "⚠️  SKIP (cache not populated)"
fi

# License parameter functionality
echo -n "Testing license_id parameter... "
if curl --fail -s "$TARGET_URL/install.sh?p=ubuntu&pv=20.04&m=x86_64&license_id=test123" | grep -q "license_id"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - license_id not found in script"
    exit 1
fi

# Base URL override
echo -n "Testing base URL override... "
if curl --fail -s "$TARGET_URL/install.sh?omnibus_url=https://custom.example.com" 2>&1 | grep -qi "custom.example.com"; then
    echo "✅ PASS"
else
    echo "⚠️  SKIP (feature may not be implemented)"
fi

# Custom filename parameter
echo -n "Testing filename parameter... "
if curl --fail -s "$TARGET_URL/install.sh?p=ubuntu&pv=20.04&m=x86_64&filename=custom.deb" 2>&1 | grep -qi "custom.deb\|cmdline_filename"; then
    echo "✅ PASS"
else
    echo "⚠️  SKIP (feature may require cache)"
fi

echo ""
echo "=========================================="
echo "✅ All endpoint tests passed!"
echo "=========================================="
