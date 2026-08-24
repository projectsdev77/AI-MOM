-- Tasks/habits now support a custom category (any text someone types),
-- not just the fixed set the app shipped with — so `category` can no
-- longer be a closed Postgres enum. Widen it to plain text, keeping
-- every existing value exactly as-is (an enum member's text is its
-- name), then drop the now-unused enum type.
alter table tasks
  alter column category type text using category::text;

alter table tasks
  alter column category set default 'personal';

drop type if exists task_category;
