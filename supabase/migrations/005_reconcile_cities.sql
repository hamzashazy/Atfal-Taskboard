-- Reconcile atfal_cities with the current official city list. Cities not on
-- the list are deactivated (never deleted — deleting would cascade-fail
-- against any existing users/tasks/assignments tied to them, and history
-- should stay intact). Existing rows are matched by name and reactivated if
-- they'd been deactivated earlier; anything missing is inserted fresh.

insert into public.atfal_cities (name) values
  ('Islamabad'), ('Karachi'), ('Peshawar'), ('Lahore'), ('Rahim Yar Khan'),
  ('Sahiwal'), ('Dera Ismail Khan'), ('Rawalpindi'), ('Sialkot'), ('Multan'),
  ('Mirpur Khas'), ('Abbottabad'), ('Wah Cantt'), ('Chakwal'), ('Swat'),
  ('Sheikhupura'), ('Mardan'), ('Sadiqabad'), ('Charsadda'), ('Quetta'),
  ('Hyderabad'), ('Murree'), ('Nowshera'), ('Umerkot'), ('Kot Addu'), ('Haripur')
on conflict (name) do update set active = true;

update public.atfal_cities set active = false
where name not in (
  'Islamabad', 'Karachi', 'Peshawar', 'Lahore', 'Rahim Yar Khan',
  'Sahiwal', 'Dera Ismail Khan', 'Rawalpindi', 'Sialkot', 'Multan',
  'Mirpur Khas', 'Abbottabad', 'Wah Cantt', 'Chakwal', 'Swat',
  'Sheikhupura', 'Mardan', 'Sadiqabad', 'Charsadda', 'Quetta',
  'Hyderabad', 'Murree', 'Nowshera', 'Umerkot', 'Kot Addu', 'Haripur'
);
