-- MedCasa: campi facoltativi per la scheda medicinale
-- Eseguire nel SQL Editor del progetto Supabase.
-- Non elimina né modifica i dati già registrati.
alter table public.medicines
  add column if not exists active_ingredient text,
  add column if not exists strength text,
  add column if not exists dosage_form text,
  add column if not exists storage_location text;

-- I campi sono nullable: nessuno è obbligatorio.
-- Le policy RLS esistenti continuano ad applicarsi alla tabella medicines.
