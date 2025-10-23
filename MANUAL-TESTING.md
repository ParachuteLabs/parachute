# Manual Testing Checklist

## Purpose
This checklist ensures the Parachute chat experience matches industry standards (Claude Desktop, ChatGPT) through systematic manual testing.

## Test Environment Setup

- [ ] Backend server running on `localhost:8080`
- [ ] Flutter app running on macOS
- [ ] WebSocket connection established (check backend logs for "WebSocket connection established")
- [ ] Test space and conversation created
- [ ] Backend logs visible in terminal
- [ ] Flutter logs visible (run with `flutter run -v`)

---

## 1. Basic Streaming Experience

### Test: Send Simple Message
**Prompt**: "What is 2+2?"

**Expected Behavior**:
- [ ] Click send → "..." appears **immediately** (< 100ms)
- [ ] Loading spinner shows next to "..."
- [ ] First text chunk appears within **2 seconds**
- [ ] Text streams in smoothly (word by word or phrase by phrase)
- [ ] Final message "4" appears
- [ ] Loading indicator disappears
- [ ] Message persists in chat history

**Compare to Claude Desktop**:
- [ ] Response speed feels similar
- [ ] Loading feedback is equally clear
- [ ] No noticeable lag or jank

---

## 2. Tool Call Visualization

### Test: Web Search Request
**Prompt**: "What's in the news today?"

**Expected Behavior**:
- [ ] "..." appears immediately
- [ ] Initial thinking text chunk appears (e.g., "I'll search for...")
- [ ] **Tool call indicators appear** below the text
- [ ] Each tool call shows:
  - [ ] Cloud icon (for web fetch)
  - [ ] Query text (truncated if long)
  - [ ] Spinning progress indicator
- [ ] Tool calls update to show checkmark when completed
- [ ] Response text streams in after tools complete
- [ ] Final message includes the synthesized answer

**Tool Call Details to Verify**:
- [ ] Icon matches tool type (cloud for fetch, document for read, etc.)
- [ ] Title text is readable and makes sense
- [ ] Status animates from pending (spinner) → completed (checkmark)
- [ ] Multiple tool calls stack vertically without overlapping
- [ ] Tool indicators don't cause layout shift

**Compare to Claude Desktop**:
- [ ] Tool visibility is similar (not hidden, but not distracting)
- [ ] Status updates feel natural
- [ ] Overall visual hierarchy matches

---

## 3. Multiple Tool Calls

### Test: Complex Research Query
**Prompt**: "Compare the latest developments in AI from Google, OpenAI, and Anthropic"

**Expected Behavior**:
- [ ] Multiple tool call indicators appear (likely 3-6 searches)
- [ ] Each has unique title
- [ ] Tools may complete out of order (verify UI handles this)
- [ ] UI doesn't freeze or stutter with many tool calls
- [ ] All tool calls eventually show completed status
- [ ] Streaming text begins after tools complete
- [ ] Final message is coherent

**Performance Check**:
- [ ] UI remains responsive (can scroll during streaming)
- [ ] No frame drops (animations stay smooth)
- [ ] Memory doesn't spike excessively

---

## 4. Streaming Text Quality

### Test: Long Response
**Prompt**: "Write a detailed explanation of how WebSockets work, including the handshake, frame format, and use cases"

**Expected Behavior**:
- [ ] Text streams in continuously (not in large bursts)
- [ ] Markdown formatting renders correctly (headers, lists, code blocks)
- [ ] Auto-scroll keeps newest content visible
- [ ] Can manually scroll up while streaming continues
- [ ] Auto-scroll resumes if scrolled back to bottom
- [ ] No text appears garbled or out of order
- [ ] Whole response feels cohesive

**Streaming Characteristics**:
- [ ] Chunks arrive at consistent rate
- [ ] No long pauses between chunks (unless tool calls)
- [ ] Punctuation and spacing correct
- [ ] Code blocks syntax-highlighted properly

---

## 5. Error Handling

### Test: Network Interruption
**Setup**: Disconnect WiFi or kill backend during streaming

**Expected Behavior**:
- [ ] Frontend shows connection error message
- [ ] Partial message remains visible
- [ ] Can retry sending message
- [ ] WebSocket reconnects automatically when network restored

### Test: Backend Error
**Setup**: Send message that might cause backend error

**Expected Behavior**:
- [ ] Error message shown to user
- [ ] Previous messages remain intact
- [ ] Can continue conversation after error

---

## 6. Multi-Conversation Handling

### Test: Switch Conversations During Streaming
**Setup**:
1. Create 2 conversations
2. Send message in Conversation A
3. While streaming, switch to Conversation B
4. Send message in Conversation B

**Expected Behavior**:
- [ ] Conversation A streaming stops when navigated away
- [ ] Conversation A final message saved correctly
- [ ] Conversation B streaming starts independently
- [ ] Switching back to A shows complete message
- [ ] No cross-contamination between conversations
- [ ] WebSocket stays connected

---

## 7. Performance & Resource Usage

### Test: Long Conversation Session
**Setup**: Have a conversation with 20+ back-and-forth messages

**Expected Behavior**:
- [ ] App doesn't slow down over time
- [ ] Memory usage stays reasonable (check Activity Monitor)
- [ ] Scrolling remains smooth
- [ ] Messages load quickly when scrolling up
- [ ] WebSocket connection stays stable

**Benchmarks** (check Activity Monitor):
- [ ] Memory: < 200MB for Flutter app
- [ ] CPU: < 30% during streaming
- [ ] No memory leaks (memory returns to baseline after streaming)

---

## 8. Edge Cases

### Test: Very Long Tool Call Title
**Prompt**: "Search for 'How to implement a highly scalable, fault-tolerant, distributed system with microservices architecture, event-driven design, and comprehensive monitoring'"

**Expected Behavior**:
- [ ] Tool call title truncates gracefully with ellipsis
- [ ] UI doesn't overflow or break
- [ ] Can still read enough to understand what tool is doing

### Test: Rapid Message Sending
**Setup**: Send 3 messages quickly in succession

**Expected Behavior**:
- [ ] All messages queued and processed
- [ ] Streaming handles queue correctly
- [ ] No messages lost
- [ ] Responses appear in correct order

### Test: Empty or Whitespace Message
**Setup**: Try to send empty message or only spaces

**Expected Behavior**:
- [ ] Send button disabled or message rejected
- [ ] Clear feedback why message can't be sent

---

## 9. Visual Polish

### Test: Visual Consistency
Check across different scenarios:

**Message Bubbles**:
- [ ] Consistent padding and margins
- [ ] User messages aligned right, assistant left
- [ ] Clear visual distinction between user/assistant
- [ ] Timestamps present and readable

**Tool Call Indicators**:
- [ ] Icons crisp and clear (not pixelated)
- [ ] Colors match app theme
- [ ] Animations smooth (no jank)
- [ ] Layout doesn't shift when status changes

**Loading States**:
- [ ] Spinner size and color appropriate
- [ ] "..." text properly styled
- [ ] Loading bubble same style as regular messages

**Dark Mode** (if supported):
- [ ] All elements visible in dark mode
- [ ] Contrast ratios meet accessibility standards

---

## 10. Comparison to Industry Standards

### Claude Desktop Comparison

**Similarities to Achieve**:
- [ ] Instant feedback on message send
- [ ] Smooth streaming (no stuttering)
- [ ] Clear tool indicators
- [ ] Professional, clean UI
- [ ] Responsive even during heavy processing

**Key Differences** (document these):
- Feature parity: ___
- Performance: ___
- UX smoothness: ___

### ChatGPT Comparison

**Similarities to Achieve**:
- [ ] Fast perceived response time
- [ ] Typing indicator while waiting
- [ ] Natural streaming cadence
- [ ] Clear message boundaries
- [ ] Easy to read markdown

**Key Differences** (document these):
- Feature parity: ___
- Performance: ___
- UX smoothness: ___

---

## 11. Accessibility

### Test: Keyboard Navigation
- [ ] Can navigate chat with keyboard only
- [ ] Tab order makes sense
- [ ] Can send message with Enter key
- [ ] Can scroll with arrow keys

### Test: Screen Reader (VoiceOver)
- [ ] Messages announced correctly
- [ ] Loading states communicated
- [ ] Tool calls described meaningfully

---

## Test Session Notes

**Date**: ___________
**Tester**: ___________
**Build**: ___________

### Issues Found

| # | Severity | Description | Reproduce Steps | Status |
|---|----------|-------------|----------------|--------|
| 1 |  |  |  |  |
| 2 |  |  |  |  |
| 3 |  |  |  |  |

### Overall Assessment

**Streaming Experience**: ☐ Excellent  ☐ Good  ☐ Needs Work  ☐ Poor

**Tool Call Visualization**: ☐ Excellent  ☐ Good  ☐ Needs Work  ☐ Poor

**Performance**: ☐ Excellent  ☐ Good  ☐ Needs Work  ☐ Poor

**Comparison to Claude Desktop**: ☐ At Parity  ☐ Close  ☐ Needs Improvement

**Comparison to ChatGPT**: ☐ At Parity  ☐ Close  ☐ Needs Improvement

**Ready for Production?**: ☐ Yes  ☐ No  ☐ With Fixes

### Subjective Notes

What feels good:
___

What needs improvement:
___

Blocking issues for production:
___

Nice-to-have improvements:
___
