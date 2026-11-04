export const chunk = (delta = {}, finish_reason = null) => ({ choices: [{ index: 0, delta, finish_reason }] });
export const frame = value => `data: ${typeof value === 'string' ? value : JSON.stringify(value)}\n\n`;
export const textStream = text => frame(chunk({ content: text })) + frame(chunk({}, 'stop')) + frame('[DONE]');
