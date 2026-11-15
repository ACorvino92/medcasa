-- MedCasa: quantità residue facoltative per lotto.
-- Eseguire una sola volta nel SQL Editor del progetto Supabase.
-- Le confezioni esistenti restano invariate.
alter table public.lots
  add column if not exists units_per_pack integer,
  add column if not exists remaining_units integer;

alter table public.lots
  drop constraint if exists lots_units_per_pack_positive;
alter table public.lots
  add constraint lots_units_per_pack_positive
  check (units_per_pack is null or units_per_pack > 0);

alter table public.lots
  drop constraint if exists lots_remaining_units_valid;
alter table public.lots
  add constraint lots_remaining_units_valid
  check (
    (units_per_pack is null and remaining_units is null)
    or
    (units_per_pack is not null and remaining_units is not null
      and remaining_units >= 0 and remaining_units <= units_per_pack)
  );

-- Significato: quantity = numero totale di confezioni del lotto.
-- Quando presenti, units_per_pack e remaining_units descrivono
-- una sola confezione aperta, inclusa in quantity.
-- Se la confezione aperta si esaurisce, quantity va decrementata
-- e remaining_units va azzerata o rimossa in una transazione.
