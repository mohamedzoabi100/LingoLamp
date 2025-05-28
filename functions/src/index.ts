// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {GoogleGenerativeAI} from '@google/generative-ai';

admin.initializeApp();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(functions.config().gemini.api_key);

interface PhraseRequest {
  topic: string;
  userId?: string;
}

interface GeneratedPhrase {
  english: string;
  spanish: string;
  category: string;
  difficulty: string;
}

export const generatePhrases = functions.https.onCall(
  async (data: PhraseRequest, context) => {
    try {
      // Allow both authenticated and unauthenticated users
      console.log('Function called by:', context.auth?.uid || 'guest user');

      // Validate input
      if (!data.topic || data.topic.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument', 'Topic is required'
        );
      }

      const topic = data.topic.trim();
      console.log('Generating phrases for topic:', topic);

      // Check for cached phrases first (without orderBy)
      try {
        const cachedResults = await admin.firestore()
          .collection('ai_phrase_cache')
          .where('topic', '==', topic.toLowerCase())
          .limit(1)
          .get();

        if (!cachedResults.empty) {
          const cachedData = cachedResults.docs[0].data();
          console.log('Found cached phrases:', cachedData.phrases.length);
          return {
            success: true,
            topic: topic,
            phrases: cachedData.phrases,
            count: cachedData.phrases.length,
            cached: true,
          };
        }
      } catch (cacheError) {
        console.log('Cache check failed, proceeding with generation:', cacheError);
      }

      // Create structured prompt for Gemini
      const prompt = `
You are a language learning assistant. Generate 8-10 useful phrases related to "${topic}" for English speakers learning Spanish.

Please return ONLY a valid JSON array in this exact format:
[
  {
    "english": "English phrase here",
    "spanish": "Spanish translation here",
    "category": "${topic}",
    "difficulty": "beginner"
  }
]

Rules:
1. Focus on practical, commonly used phrases
2. Mix beginner and intermediate difficulty levels
3. Make sure Spanish translations are accurate
4. Keep phrases conversational and useful
5. Return ONLY the JSON array, no other text
6. Ensure valid JSON format

Topic: ${topic}
`;

      // Check if Gemini API key is available
      if (!functions.config().gemini || !functions.config().gemini.api_key) {
        throw new functions.https.HttpsError(
          'failed-precondition', 'Gemini API key not configured'
        );
      }

      // Call Gemini API with updated model name
      const model = genAI.getGenerativeModel({model: 'gemini-1.5-flash'});
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      console.log('Gemini response received:', text.substring(0, 200) + '...');

      // Parse JSON response
      let phrases: GeneratedPhrase[];
      try {
        // Clean the response - remove any markdown formatting
        const cleanedText = text.replace(/```json\n?/g, '')
          .replace(/```\n?/g, '').trim();
        phrases = JSON.parse(cleanedText);
      } catch (parseError) {
        console.error('Failed to parse Gemini response:', text);
        throw new functions.https.HttpsError(
          'internal', 'Failed to parse AI response'
        );
      }

      // Validate response structure
      if (!Array.isArray(phrases) || phrases.length === 0) {
        throw new functions.https.HttpsError(
          'internal', 'Invalid response format from AI'
        );
      }

      console.log('Successfully generated', phrases.length, 'phrases');

      // Cache the results in Firestore (simplified)
      try {
        const cacheData = {
          topic: topic.toLowerCase(),
          phrases: phrases,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          userId: context.auth?.uid || 'guest',
        };

        await admin.firestore()
          .collection('ai_phrase_cache')
          .add(cacheData);

        console.log('Phrases cached successfully');
      } catch (cacheError) {
        console.error('Failed to cache phrases:', cacheError);
        // Don't fail the entire function if caching fails
      }

      return {
        success: true,
        topic: topic,
        phrases: phrases,
        count: phrases.length,
      };
    } catch (error) {
      console.error('Error generating phrases:', error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Log more details about the error
      console.error('Full error object:', JSON.stringify(error, null, 2));

      throw new functions.https.HttpsError(
        'internal', `Failed to generate phrases: ${error.message || error}`
      );
    }
  }
);

// Simplified function to get cached phrases
export const getCachedPhrases = functions.https.onCall(
  async (data: {topic: string}, context) => {
    try {
      // Allow both authenticated and unauthenticated users
      console.log('Cache function called by:', context.auth?.uid || 'guest user');

      const topic = data.topic.toLowerCase().trim();
      console.log('Looking for cached phrases for topic:', topic);

      // Simple query without orderBy to avoid index issues
      const cachedResults = await admin.firestore()
        .collection('ai_phrase_cache')
        .where('topic', '==', topic)
        .limit(1)
        .get();

      if (cachedResults.empty) {
        console.log('No cached phrases found for topic:', topic);
        return {
          success: false,
          message: 'No cached phrases found for this topic',
        };
      }

      const cachedData = cachedResults.docs[0].data();
      console.log('Found cached phrases:', cachedData.phrases.length);

      return {
        success: true,
        topic: topic,
        phrases: cachedData.phrases,
        count: cachedData.phrases.length,
        cached: true,
      };
    } catch (error) {
      console.error('Error getting cached phrases:', error);
      console.error('Full error object:', JSON.stringify(error, null, 2));
      throw new functions.https.HttpsError(
        'internal', `Failed to get cached phrases: ${error.message || error}`
      );
    }
  }
);