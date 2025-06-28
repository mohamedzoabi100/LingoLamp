// functions/src/index.ts - FIXED VERSION - DEPLOY THIS!
import * as functions from 'firebase-functions';
import { GoogleGenerativeAI } from '@google/generative-ai';

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI("AIzaSyBx03Wja1HkkfTMIs4SeVgbcp7uAW28FtU");

interface PhraseRequest {
  topic: string;
  forceNew?: boolean;
  timestamp?: number;
  existingPhrases?: string[];
  requestType?: 'generateMore' | 'initial';
  generationNumber?: number;
  isMoreGeneration?: boolean;
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
    
    const { 
      topic, 
      forceNew = false, 
      existingPhrases = [], 
      requestType = 'initial',
      generationNumber = 1,
      isMoreGeneration = false
    } = data;
    
    if (!topic || typeof topic !== 'string' || topic.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Topic is required and must be a non-empty string.');
    }

    console.log(`📊 Processing ${requestType} request for "${topic}" (Generation #${generationNumber})`);
    console.log(`🔄 ForceNew: ${forceNew}, IsMoreGeneration: ${isMoreGeneration}`);
    console.log(`📝 Existing phrases to avoid: ${existingPhrases.length}`);

    // CRITICAL: For "Generate More" requests, ALWAYS generate new phrases (don't use cache)
    if (requestType === 'generateMore' || isMoreGeneration || forceNew) {
      console.log('🚀 Bypassing cache - generating fresh phrases via AI');
    } else {
      console.log('📦 This is initial generation - proceeding with AI generation');
    }

    // Create enhanced prompts based on request type and generation number
    let prompt: string;
    
    if (requestType === 'generateMore' && existingPhrases.length > 0) {
      // GENERATE MORE: Include existing phrases to avoid duplicates
      prompt = `Generate 8-12 NEW and DIFFERENT Spanish language learning phrases for the topic "${topic}".

THIS IS GENERATION #${generationNumber} - You must provide COMPLETELY DIFFERENT phrases from what I already have.

EXISTING PHRASES I ALREADY HAVE (DO NOT REPEAT THESE):
${existingPhrases.map((phrase, idx) => `${idx + 1}. ${phrase}`).join('\n')}

REQUIREMENTS FOR NEW PHRASES:
- Generate phrases that are COMPLETELY DIFFERENT from the existing ones above
- Focus on different aspects, situations, or contexts within "${topic}"
- Make them practical and useful for travelers/Spanish learners
- Include a mix of difficulty levels (beginner, intermediate, advanced)
- Include both formal and informal expressions where appropriate
- Consider more specific, nuanced, or advanced scenarios for this topic
- Avoid repeating similar sentence structures or vocabulary from existing phrases

Return ONLY a JSON array with this exact format:
[
  {
    "english": "English phrase here",
    "spanish": "Spanish translation here", 
    "category": "${topic}",
    "difficulty": "beginner|intermediate|advanced"
  }
]

Generate phrases that cover NEW scenarios within "${topic}" that I don't already have covered.`;

    } else if (isMoreGeneration && generationNumber > 1) {
      // SUBSEQUENT GENERATIONS: Even without existing phrases, ask for more advanced content
      prompt = `Generate 10-12 Spanish language learning phrases for the topic "${topic}".

THIS IS GENERATION #${generationNumber} for this topic, so provide MORE ADVANCED and SPECIFIC phrases.

Since this is not the first generation:
- Focus on more sophisticated language and situations
- Include advanced vocabulary and complex sentence structures  
- Cover specialized or nuanced scenarios within "${topic}"
- Include cultural context and formal/informal register variations
- Provide phrases for specific sub-topics or advanced situations

REQUIREMENTS:
- Make them practical but more advanced than basic phrases
- Include intermediate to advanced difficulty levels
- Cover different aspects and scenarios within the topic
- Include both formal and informal expressions
- Return ONLY a JSON array with this exact format:

[
  {
    "english": "English phrase here",
    "spanish": "Spanish translation here",
    "category": "${topic}",
    "difficulty": "beginner|intermediate|advanced"
  }
]

Focus on advanced and specialized phrases for "${topic}".`;

    } else {
      // INITIAL GENERATION: Standard prompt for first-time generation
      prompt = `Generate 10-15 practical Spanish language learning phrases for the topic "${topic}".

REQUIREMENTS:
- Make them useful for travelers and Spanish learners
- Include a mix of difficulty levels (beginner, intermediate, advanced)
- Cover different scenarios and situations within the topic
- Include both formal and informal expressions where appropriate
- Focus on practical, real-world phrases that learners would actually use
- Return ONLY a JSON array with this exact format:

[
  {
    "english": "English phrase here",
    "spanish": "Spanish translation here",
    "category": "${topic}",
    "difficulty": "beginner|intermediate|advanced"
  }
]

Focus on essential and commonly needed phrases for "${topic}".`;
    }

    console.log(`📝 Using ${requestType} prompt for topic: ${topic}`);
    if (requestType === 'generateMore') {
      console.log(`🔄 Avoiding ${existingPhrases.length} existing phrases`);
    }

    // Generate content using Gemini
    const model = genAI.getGenerativeModel({ 
      model: 'gemini-1.5-flash',
      generationConfig: {
        temperature: requestType === 'generateMore' ? 0.9 : 0.7, // Higher creativity for "generate more"
        topP: 0.9,
        topK: 40,
        maxOutputTokens: 2048,
      }
    });
    
    console.log('🤖 Calling Gemini AI to generate phrases...');
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    
    console.log('🤖 Raw AI response received, length:', text.length);
    console.log('🤖 Raw AI response preview:', text.substring(0, 500));

    // Parse the JSON response
    const jsonMatch = text.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      console.error('❌ No JSON array found in AI response');
      console.error('❌ Full response:', text);
      throw new functions.https.HttpsError('internal', 'Failed to parse AI response as JSON array.');
    }

    let phrases: GeneratedPhrase[];
    try {
      phrases = JSON.parse(jsonMatch[0]);
      console.log(`✅ Successfully parsed ${phrases.length} phrases from AI`);
    } catch (parseError) {
      console.error('❌ JSON parsing error:', parseError);
      console.error('❌ JSON content:', jsonMatch[0]);
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

    // Enhanced duplicate filtering for "generate more" requests
    let finalPhrases = validPhrases;
    if (requestType === 'generateMore' && existingPhrases.length > 0) {
      console.log('🔍 Filtering duplicates...');
      const initialCount = finalPhrases.length;
      
      finalPhrases = validPhrases.filter(phrase => {
        const englishLower = phrase.english.toLowerCase();
        
        // Check for duplicates or very similar phrases
        const isDuplicate = existingPhrases.some(existing => {
          const existingLower = existing.toLowerCase();
          
          // Exact match
          if (existingLower === englishLower) return true;
          
          // Contains check (both ways) - but allow if significant difference
          if (existingLower.includes(englishLower) || englishLower.includes(existingLower)) {
            return Math.abs(existingLower.length - englishLower.length) < 10;
          }
          
          // Check for similar key words (basic similarity)
          const existingWords = existingLower.split(' ').filter(w => w.length > 3);
          const newWords = englishLower.split(' ').filter(w => w.length > 3);
          const commonWords = existingWords.filter(w => newWords.includes(w));
          
          // If more than 60% of significant words are the same, consider it similar
          if (existingWords.length > 0 && (commonWords.length / existingWords.length) > 0.6) {
            return true;
          }
          
          return false;
        });
        
        if (isDuplicate) {
          console.log(`🔄 Filtered out similar phrase: "${phrase.english}"`);
        }
        
        return !isDuplicate;
      });
      
      console.log(`📊 Filtered from ${initialCount} to ${finalPhrases.length} unique phrases`);
    }

    // Ensure we have a minimum number of phrases for "generate more"
    if (finalPhrases.length < 3 && requestType === 'generateMore') {
      console.warn('⚠️ Very few unique phrases generated. This might indicate the AI is running out of variations.');
    }

    console.log(`✅ Returning ${finalPhrases.length} ${requestType === 'generateMore' ? 'NEW' : ''} phrases for topic: ${topic}`);

    return {
      success: true,
      phrases: finalPhrases,
      count: finalPhrases.length,
      requestType,
      topic,
      generationNumber,
      isMoreGeneration,
      cached: false // IMPORTANT: Always false for fresh generations
    };

  } catch (error) {
    console.error('❌ Error in generatePhrases:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', `Failed to generate phrases: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
});

// Updated getCachedPhrases function - returns empty for generate more requests
export const getCachedPhrases = functions.https.onCall(async (data: { topic: string, requestType?: string }, context) => {
  try {
    console.log('📦 getCachedPhrases called for topic:', data.topic, 'requestType:', data.requestType);
    
    // For "generateMore" requests, always return empty to force fresh generation
    if (data.requestType === 'generateMore') {
      console.log('🔄 Generate More request - returning empty to force fresh generation');
      return {
        success: false,
        message: 'No cached phrases for generate more requests',
        phrases: [],
        cached: false
      };
    }
    
    // For initial requests, you can implement caching logic here
    // For now, always return empty to force generation via AI
    
    return {
      success: false,
      message: 'No cached phrases found',
      phrases: [],
      cached: false
    };
  } catch (error) {
    console.error('❌ Error in getCachedPhrases:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get cached phrases');
  }
});