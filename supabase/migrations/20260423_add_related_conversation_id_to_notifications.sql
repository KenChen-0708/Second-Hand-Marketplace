alter table public.notifications
  add column if not exists related_conversation_id varchar(20)
    references public.chat_conversations(id) on delete set null;

create index if not exists idx_notifications_related_conversation_id
  on public.notifications(related_conversation_id);
