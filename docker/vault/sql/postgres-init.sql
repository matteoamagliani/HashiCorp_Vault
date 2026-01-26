-- postgres-init.sql
-- Create a demo table to make the "read-only" role meaningful.
CREATE TABLE IF NOT EXISTS public.demo_data (
  id SERIAL PRIMARY KEY,
  note TEXT NOT NULL
);

INSERT INTO public.demo_data(note) VALUES
  ('hello from postgres init'),
  ('vault dynamic creds demo');
