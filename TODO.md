# TODO: Implement Chat History Grouping by chat_id

## Tasks
- [ ] Replace _groupMessagesIntoChats() function with new version that groups by chat_id
- [ ] Modify _showChatHistory() to select 'message, response, created_at, chat_id'
- [ ] Replace _startNewChat() with new version that queries Supabase for max chat_id and sets _currentChatId

## Followup Steps
- [ ] Test the app to ensure chat history loads and groups correctly by chat_id
- [ ] Verify new chat creation assigns proper chat_id
