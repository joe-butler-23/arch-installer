#!/usr/bin/env python3
"""
Test script for agentic-doc library
Tests the installation and API connection
"""

import os
from agentic_doc.parse import parse

def test_agentic_doc():
    """Test the agentic-doc library installation and API connection"""
    
    # Check if API key is set
    api_key = os.getenv('LANDINGAI_API_KEY')
    if not api_key:
        print("❌ Error: LANDINGAI_API_KEY environment variable not set")
        return False
    
    print(f"✅ API Key found: {api_key[:20]}...")
    
    try:
        # Test with a simple URL (this will test the API connection)
        print("🔄 Testing API connection with a sample document...")
        
        # Use a simple test document URL
        test_url = "https://www.rbcroyalbank.com/banking-services/_assets-custom/pdf/eStatement.pdf"
        
        results = parse([test_url])
        
        if results and len(results) > 0:
            print("✅ API connection successful!")
            print(f"📄 Parsed document: {results[0].title}")
            print(f"📊 Number of chunks: {len(results[0].chunks)}")
            return True
        else:
            print("❌ No results returned from API")
            return False
            
    except Exception as e:
        print(f"❌ Error testing API: {str(e)}")
        return False

if __name__ == "__main__":
    print("🧪 Testing agentic-doc installation...")
    success = test_agentic_doc()
    
    if success:
        print("\n🎉 All tests passed! Ready to parse PDFs.")
    else:
        print("\n💥 Tests failed. Please check your setup.")
