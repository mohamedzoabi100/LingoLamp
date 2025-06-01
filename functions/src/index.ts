// functions/src/index.ts - Enhanced Firebase Function
import * as functions from 'firebase-functions';
import { GoogleGenerativeAI } from '@google/generative-ai';

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(functions.config().gemini.api_key);

interface PhraseRequest {
  topic: string;
  forceNew?: boolean;
  timestamp?: number;
  existingPhrases?: string[]; // NEW: List of existing phrases to avoid
  requestType?: 'generateMore' | 'initial'; // NEW: Type of request
}

interface GeneratedPhrase {
  english: string;
  spanish: string;
  category: string;
  difficulty: string;
}

export const generatePhrases = functions.https.onCall(async (data: PhraseRequest, context) => {
  try {
    console.log('🚀 generatePhrases called with:', JSON.stringify(data, null, 2));
    
    const { topic, forceNew = false, existingPhrases = [], requestType = 'initial' } = data;
    
    if (!topic || typeof topic !== 'string' || topic.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Topic is required and must be a non-empty string.');
    }

    // ENHANCED: Create different prompts based on request type
    let prompt: string;
    
    if (requestType === 'generateMore' && existingPhrases.length > 0) {
      // GENERATE MORE: Include existing phrases to avoid duplicates
      prompt = `Generate 8-12 NEW Spanish language learning phrases for the topic "${topic}".

IMPORTANT: I already have these phrases, so generate COMPLETELY DIFFERENT ones:
${existingPhrases.map((phrase, idx) => `${idx + 1}. ${phrase}`).join('\n')}

Requirements:
- Generate phrases that are DIFFERENT from the existing ones above
- Focus on different aspects, situations, or contexts within "${topic}"
- Make them practical and useful for travelers/learners
- Vary the difficulty levels (beginner, intermediate, advanced)
- Include formal and informal expressions
- Return ONLY a JSON array with this exact format:

[
  {
    "english": "English phrase here",
    "spanish": "Spanish translation here", 
    "category": "${topic}",
    "difficulty": "beginner|intermediate|advanced"
  }
]

Generate phrases that cover different scenarios within "${topic}" that I don't already have.`;

    } else {
      // INITIAL GENERATION: Standard prompt
      prompt = `Generate 10-15 practical Spanish language learning phrases for the topic "${topic}".

Requirements:
- Make them useful for travelers and Spanish learners
- Include a mix of difficulty levels (beginner, intermediate, advanced)
- Cover different scenarios within the topic
- Include both formal and informal expressions where appropriate
- Return ONLY a JSON array with this exact format:

[
  {
    "english": "English phrase here",
    "spanish": "Spanish translation here",
    "category": "${topic}",
    "difficulty": "beginner|intermediate|advanced"
  }
]

Focus on practical, real-world phrases that learners would actually use.`;
    }

    console.log(`📝 Using ${requestType} prompt for topic: ${topic}`);
    if (requestType === 'generateMore') {
      console.log(`🔄 Avoiding ${existingPhrases.length} existing phrases`);
    }

    // Generate content using Gemini
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    
    console.log('🤖 Raw AI response:', text);

    // Parse the JSON response
    const jsonMatch = text.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      console.error('❌ No JSON array found in AI response');
      throw new functions.https.HttpsError('internal', 'Failed to parse AI response as JSON array.');
    }

    let phrases: GeneratedPhrase[];
    try {
      phrases = JSON.parse(jsonMatch[0]);
    } catch (parseError) {
      console.error('❌ JSON parsing error:', parseError);
      throw new functions.https.HttpsError('internal', 'Failed to parse generated phrases.');
    }

    // Validate phrases
    const validPhrases = phrases.filter((phrase: any) => {
      const isValid = phrase.english && 
                     phrase.spanish && 
                     typeof phrase.english === 'string' && 
                     typeof phrase.spanish === 'string' &&
                     phrase.english.trim().length > 0 &&
                     phrase.spanish.trim().length > 0;
      
      if (!isValid) {
        console.warn('⚠️ Invalid phrase filtered out:', phrase);
      }
      
      return isValid;
    });

    if (validPhrases.length === 0) {
      throw new functions.https.HttpsError('internal', 'No valid phrases were generated.');
    }

    // ENHANCED: For "generate more" requests, try to filter out similar phrases
    let finalPhrases = validPhrases;
    if (requestType === 'generateMore' && existingPhrases.length > 0) {
      finalPhrases = validPhrases.filter(phrase => {
        // Simple similarity check - avoid exact matches or very similar phrases
        const englishLower = phrase.english.toLowerCase();
        const isDuplicate = existingPhrases.some(existing => 
          existing.toLowerCase() === englishLower ||
          existing.toLowerCase().includes(englishLower) ||
          englishLower.includes(existing.toLowerCase())
        );
        
        if (isDuplicate) {
          console.log(`🔄 Filtered out similar phrase: "${phrase.english}"`);
        }
        
        return !isDuplicate;
      });
    }

    console.log(`✅ Generated ${finalPhrases.length} ${requestType === 'generateMore' ? 'NEW' : ''} valid phrases for topic: ${topic}`);

    // Optional: Cache the result (you can implement caching logic here)
    // if (!forceNew) {
    //   await cacheResult(topic, finalPhrases);
    // }

    return {
      success: true,
      phrases: finalPhrases,
      count: finalPhrases.length,
      requestType,
      topic
    };

  } catch (error) {
    console.error('❌ Error in generatePhrases:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to generate phrases: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
});

// Keep your existing getCachedPhrases function as is
export const getCachedPhrases = functions.https.onCall(async (data: { topic: string }, context) => {
  try {
    console.log('📦 getCachedPhrases called for topic:', data.topic);
    
    // Implement your caching logic here
    // For now, return empty to force generation
    
    return {
      success: false,
      message: 'No cached phrases found',
      phrases: []
    };
  } catch (error) {
    console.error('❌ Error in getCachedPhrases:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get cached phrases');
  }
});