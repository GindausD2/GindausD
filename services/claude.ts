/**
 * Claude API service — handles streaming messages and tool use.
 * Uses @anthropic-ai/sdk with dangerouslyAllowBrowser for React Native.
 */

import Anthropic from '@anthropic-ai/sdk';
import { Message } from '@/types';
import { SYSTEM_PROMPT } from '@/constants/prompts';
import { TOOL_DEFINITIONS, executeTool } from './tools';
import { recallFacts } from './storage';

let _client: Anthropic | null = null;

function getClient(apiKey: string): Anthropic {
  if (!_client || (_client as unknown as { apiKey: string }).apiKey !== apiKey) {
    _client = new Anthropic({
      apiKey,
      dangerouslyAllowBrowser: true,
    });
  }
  return _client;
}

// Convert our internal messages to Anthropic API format
function toApiMessages(
  messages: Message[]
): Anthropic.MessageParam[] {
  return messages
    .filter((m) => !m.isStreaming)
    .map((m) => ({
      role: m.role as 'user' | 'assistant',
      content: m.content,
    }));
}

// Build a context-injected system prompt that includes user memories
async function buildSystemPrompt(): Promise<string> {
  const memories = await recallFacts();
  if (memories.length === 0) return SYSTEM_PROMPT;

  const memoryBlock = memories
    .map((m) => `- ${m.key}: ${m.value}`)
    .join('\n');

  return `${SYSTEM_PROMPT}\n\n## What You Know About the User\n${memoryBlock}`;
}

export type StreamChunk =
  | { type: 'text'; delta: string }
  | { type: 'tool_start'; toolName: string; toolId: string }
  | { type: 'tool_result'; toolId: string; toolName: string; result: string }
  | { type: 'done' }
  | { type: 'error'; message: string };

/**
 * Stream a response from Claude.
 * Yields StreamChunks for incremental UI updates.
 * Handles multi-turn tool use automatically.
 */
export async function* streamMessage(
  apiKey: string,
  messages: Message[],
  onChunk: (chunk: StreamChunk) => void
): AsyncGenerator<StreamChunk> {
  const client = getClient(apiKey);
  const systemPrompt = await buildSystemPrompt();
  const apiMessages = toApiMessages(messages);

  try {
    // Agentic loop: keep going until we get a final assistant text response
    let currentMessages = [...apiMessages];

    while (true) {
      const stream = await client.messages.stream({
        model: 'claude-sonnet-4-6',
        max_tokens: 4096,
        system: systemPrompt,
        tools: TOOL_DEFINITIONS as Anthropic.Tool[],
        messages: currentMessages,
      });

      let fullText = '';
      let stopReason: string | null = null;
      const toolUses: Array<{ id: string; name: string; input: Record<string, unknown> }> = [];
      let currentToolId = '';
      let currentToolName = '';
      let currentToolInputJson = '';

      for await (const event of stream) {
        if (event.type === 'content_block_start') {
          if (event.content_block.type === 'tool_use') {
            currentToolId = event.content_block.id;
            currentToolName = event.content_block.name;
            currentToolInputJson = '';
            const chunk: StreamChunk = { type: 'tool_start', toolName: currentToolName, toolId: currentToolId };
            onChunk(chunk);
            yield chunk;
          }
        } else if (event.type === 'content_block_delta') {
          if (event.delta.type === 'text_delta') {
            fullText += event.delta.text;
            const chunk: StreamChunk = { type: 'text', delta: event.delta.text };
            onChunk(chunk);
            yield chunk;
          } else if (event.delta.type === 'input_json_delta') {
            currentToolInputJson += event.delta.partial_json;
          }
        } else if (event.type === 'content_block_stop') {
          if (currentToolId && currentToolName) {
            let toolInput: Record<string, unknown> = {};
            try {
              toolInput = currentToolInputJson ? JSON.parse(currentToolInputJson) : {};
            } catch {
              toolInput = {};
            }
            toolUses.push({ id: currentToolId, name: currentToolName, input: toolInput });
            currentToolId = '';
            currentToolName = '';
            currentToolInputJson = '';
          }
        } else if (event.type === 'message_delta') {
          stopReason = event.delta.stop_reason ?? null;
        }
      }

      // If stop_reason is tool_use, execute tools and continue the loop
      if (stopReason === 'tool_use' && toolUses.length > 0) {
        // Add the assistant's response (with tool calls) to the conversation
        const assistantContent: Anthropic.ContentBlock[] = [];
        if (fullText) {
          assistantContent.push({ type: 'text', text: fullText });
        }
        for (const tu of toolUses) {
          assistantContent.push({
            type: 'tool_use',
            id: tu.id,
            name: tu.name,
            input: tu.input,
          });
        }
        currentMessages.push({ role: 'assistant', content: assistantContent });

        // Execute each tool and collect results
        const toolResults: Anthropic.ToolResultBlockParam[] = [];
        for (const tu of toolUses) {
          const result = await executeTool(tu.name, tu.input);
          const chunk: StreamChunk = { type: 'tool_result', toolId: tu.id, toolName: tu.name, result };
          onChunk(chunk);
          yield chunk;
          toolResults.push({ type: 'tool_result', tool_use_id: tu.id, content: result });
        }

        // Add tool results and continue
        currentMessages.push({ role: 'user', content: toolResults });
        continue; // Loop back to get Claude's next response
      }

      // We got a final response (end_turn or no more tool calls)
      const done: StreamChunk = { type: 'done' };
      onChunk(done);
      yield done;
      break;
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const errChunk: StreamChunk = { type: 'error', message };
    onChunk(errChunk);
    yield errChunk;
  }
}

/**
 * Quick non-streaming call for simple one-off requests (e.g., generating titles).
 */
export async function quickMessage(apiKey: string, prompt: string): Promise<string> {
  const client = getClient(apiKey);
  const response = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 256,
    messages: [{ role: 'user', content: prompt }],
  });
  const block = response.content[0];
  return block.type === 'text' ? block.text : '';
}
