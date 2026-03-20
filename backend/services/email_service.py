import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException
import os
from dotenv import load_dotenv

load_dotenv()

def send_otp_email(receiver_email, otp):
    """
    Sends a 6-digit OTP email to the user using Brevo API.
    """
    configuration = sib_api_v3_sdk.Configuration()
    configuration.api_key['api-key'] = os.getenv('BREVO_API_KEY')
    
    api_instance = sib_api_v3_sdk.TransactionalEmailsApi(sib_api_v3_sdk.ApiClient(configuration))
    
    sender_email = os.getenv('MAIL_FROM', 'noreply@pqcapp.com')
    subject = "Your PQC App Login Code"
    
    html_content = f"""
    <html>
        <body>
            <h3>Your login OTP is: <b>{otp}</b></h3>
            <p>Valid for 5 minutes only.</p>
            <p>Do not share this code.</p>
        </body>
    </html>
    """
    
    send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
        to=[{"email": receiver_email}],
        html_content=html_content,
        sender={"email": sender_email, "name": "PQC App"},
        subject=subject
    )

    try:
        api_response = api_instance.send_transac_email(send_smtp_email)
        print(f"OTP Email sent successfully to {receiver_email}. Response: {api_response}")
        return True
    except ApiException as e:
        print(f"Exception when calling TransactionalEmailsApi->send_transac_email: {e}")
        return False
