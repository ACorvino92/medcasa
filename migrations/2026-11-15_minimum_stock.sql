-- MedCasa: soglia facoltativa delle confezioni disponibili.
-- NULL = nessun avviso di scorta bassa per questo medicinale.
-- Le confezioni scadute saranno escluse dal calcolo nell'interfaccia.
alter table public.medicines
  add column if not exists minimum_stock integer;
alter table public.medicines
  drop constraint if exists medicines_minimum_stock_nonnegative;
alter table public.medicines
  add constraint medicines_minimum_stock_nonnegative
  check (minimum_stock is null or minimum_stock >= 0);
