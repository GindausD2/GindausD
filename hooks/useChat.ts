import { useState, useCallback, useRef, useEffect } from 'react';
import { Message } from '@/types';
import { loadMessages, saveMessages, clearMessages } from '@/services/storage';
import { streamMessage, StreamChunk } from '@/services/claude';
import { WELCOME_MESSAGE } from '@/constants/prompts';

function makeId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

function makeWelcome(): Message {
  return {
    id: makeId(),
    role: 'assistant',
    content: WELCOME_MESSAGE,
    timestamp: Date.now(),
  };
}

export function useChat(apiKey: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeToolName, setActiveToolName] = useState<string | null>(null);
  const abortRef = useRef<boolean>(false);

  // Load persisted messages on mount
  useEffect(() => {
    loadMessages().then((stored) => {
      if (stored.length === 0) {
        const welcome = makeWelcome();
        setMessages([welcome]);
      } else {
        // Strip any leftover streaming flags
        setMessages(stored.map((m) => ({ ...m, isStreaming: false })));
      }
    });
  }, []);

  // Persist messages whenever they change (debounced via useEffect)
  useEffect(() => {
    if (messages.length > 0) {
      const finalMessages = messages.filter((m) => !m.isStreaming);
      saveMessages(finalMessages);
    }
  }, [messages]);

  const sendMessage = useCallback(
    async (userText: string) => {
      if (!userText.trim() || isLoading) return;
      if (!apiKey) {
        setError('No API key set. Please add your Anthropic API key in Settings.');
        return;
      }

      setError(null);
      abortRef.current = false;

      // Add user message
      const userMsg: Message = {
        id: makeId(),
        role: 'user',
        content: userText.trim(),
        timestamp: Date.now(),
      };

      // Add placeholder AI message that will be filled via streaming
      const aiMsgId = makeId();
      const aiMsg: Message = {
        id: aiMsgId,
        role: 'assistant',
        content: '',
        timestamp: Date.now(),
        isStreaming: true,
      };

      setMessages((prev) => [...prev, userMsg, aiMsg]);
      setIsLoading(true);

      let accText = '';

      try {
        // We need all messages (including the new user one) for context
        const contextMessages = [...messages.filter((m) => !m.isStreaming), userMsg];

        const handleChunk = (chunk: StreamChunk) => {
          if (abortRef.current) return;

          if (chunk.type === 'text') {
            accText += chunk.delta;
            setMessages((prev) =>
              prev.map((m) =>
                m.id === aiMsgId ? { ...m, content: accText, isStreaming: true } : m
              )
            );
          } else if (chunk.type === 'tool_start') {
            setActiveToolName(chunk.toolName);
          } else if (chunk.type === 'tool_result') {
            setActiveToolName(null);
          } else if (chunk.type === 'done') {
            setMessages((prev) =>
              prev.map((m) =>
                m.id === aiMsgId ? { ...m, content: accText, isStreaming: false } : m
              )
            );
          } else if (chunk.type === 'error') {
            setError(chunk.message);
            setMessages((prev) =>
              prev.map((m) =>
                m.id === aiMsgId
                  ? { ...m, content: `Error: ${chunk.message}`, isStreaming: false }
                  : m
              )
            );
          }
        };

        // Consume the async generator
        for await (const _chunk of streamMessage(apiKey, contextMessages, handleChunk)) {
          if (abortRef.current) break;
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        setError(msg);
        setMessages((prev) =>
          prev.map((m) =>
            m.id === aiMsgId ? { ...m, content: `Error: ${msg}`, isStreaming: false } : m
          )
        );
      } finally {
        setIsLoading(false);
        setActiveToolName(null);
      }
    },
    [apiKey, isLoading, messages]
  );

  const clearConversation = useCallback(async () => {
    abortRef.current = true;
    await clearMessages();
    setMessages([makeWelcome()]);
    setError(null);
    setIsLoading(false);
    setActiveToolName(null);
  }, []);

  const stopStreaming = useCallback(() => {
    abortRef.current = true;
    setIsLoading(false);
    setActiveToolName(null);
    // Finalize any streaming message
    setMessages((prev) =>
      prev.map((m) => (m.isStreaming ? { ...m, isStreaming: false } : m))
    );
  }, []);

  return {
    messages,
    isLoading,
    error,
    activeToolName,
    sendMessage,
    clearConversation,
    stopStreaming,
  };
}
