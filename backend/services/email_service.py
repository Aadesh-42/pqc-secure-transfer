import requests
import os
from dotenv import load_dotenv

load_dotenv()

def send_otp_email(email: str, otp: str):
    """
    Sends a 6-digit OTP email to the user using Brevo REST API with requests.
    """
    print(f"DEBUG: Attempting to send OTP to {email}")
    print(f"DEBUG: Using OTP code: {otp}")
    
    api_key = os.getenv("BREVO_API_KEY")
    sender_email = os.getenv("MAIL_FROM", "aadi.angane07@gmail.com")
    
    if not api_key:
        print("DEBUG ERROR: BREVO_API_KEY is not set in environment variables.")
        return False
        
    url = "https://api.brevo.com/v3/smtp/email"
    
    headers = {
        "accept": "application/json",
        "api-key": api_key,
        "content-type": "application/json"
    }
    
    data = {
        "sender": {
            "name": "PQC Secure App",
            "email": sender_email
        },
        "to": [{"email": email}],
        "subject": "Your PQC App Login OTP",
        "htmlContent": f"""
            <h2>PQC Secure App Login</h2>
            <p>Your OTP code is:</p>
            <h1 style='color:blue'>{otp}</h1>
            <p>Valid for 5 minutes only.</p>
            <p>Do not share this code.</p>
        """
    }
    
    try:
        response = requests.post(url, json=data, headers=headers)
        print(f"DEBUG: Brevo response status code: {response.status_code}")
        print(f"DEBUG: Brevo response body: {response.text}")
        
        if response.status_code == 201:
            print(f"SUCCESS: OTP Email sent successfully to {email}")
            return True
        else:
            print(f"FAILURE: Failed to send email. Status code: {response.status_code}")
            return False
    except Exception as e:
        print(f"DEBUG ERROR: Exception occurred while sending email: {e}")
        return False
