const functions = require("firebase-functions");
const axios = require("axios"); // For making HTTP requests

// Firebase Cloud Function to handle chatbot requests
exports.chatBot = functions.https.onRequest(async (req, res) => {
  const userInput = req.body.message || "Hello"; // Get user input from the request body

  // Gemini API endpoint
  const geminiApiUrl =
    "https://us-central1-aiplatform.googleapis.com/v1/projects/zero-98e8f/locations/us-central1/models/text-bison:predict";

  try {
    // POST request to the Gemini API
    const response = await axios.post(
      geminiApiUrl,
      {
        instances: [
          {
            content: userInput, // User's input message
          },
        ],
        parameters: {
          temperature: 0.7, // Creativity of the response
          maxOutputTokens: 256, // Maximum tokens in the response
          topK: 40, // Limit top-K sampling
          topP: 0.8, // Limit nucleus sampling
        },
      },
      {
        headers: {
          Authorization: `Bearer AIzaSyCTGOqH6fcr4Zng3o7RH9touAg7iG82S3I`, // Replace with your API key
          "Content-Type": "application/json",
        },
      }
    );

    // Parse and send back the response from the Gemini API
    const chatbotResponse =
      response.data.predictions[0]?.content || "No response from chatbot.";
    res.status(200).send({ response: chatbotResponse });
  } catch (error) {
    console.error("Error connecting to Gemini API:", error.message);
    res
      .status(500)
      .send({ error: "Failed to connect to the chatbot API.", details: error.message });
  }
});
