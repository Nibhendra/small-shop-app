function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function getTwilioConfig() {
  return {
    accountSid: requireEnv('TWILIO_ACCOUNT_SID'),
    authToken: requireEnv('TWILIO_AUTH_TOKEN'),
    whatsappFrom: requireEnv('TWILIO_WHATSAPP_FROM')
  };
}

module.exports = {
  getTwilioConfig
};
