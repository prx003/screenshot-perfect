CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  );
$$;
REVOKE ALL ON FUNCTION public.has_role(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, text) TO authenticated, service_role;

CREATE TABLE public.aics_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_key text NOT NULL UNIQUE CHECK (session_key IN ('web-development', 'robotics', 'ai-development', 'vfx')),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 120),
  description text NOT NULL DEFAULT '',
  starts_at timestamptz,
  is_open boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.aics_sessions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.aics_sessions TO authenticated;
GRANT ALL ON public.aics_sessions TO service_role;
ALTER TABLE public.aics_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view event sessions" ON public.aics_sessions FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Admins can manage event sessions" ON public.aics_sessions FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.aics_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_ref text NOT NULL UNIQUE,
  full_name text NOT NULL CHECK (length(btrim(full_name)) BETWEEN 1 AND 100),
  email text NOT NULL CHECK (length(btrim(email)) BETWEEN 3 AND 255),
  phone text NOT NULL CHECK (length(btrim(phone)) BETWEEN 3 AND 32),
  institution text NOT NULL CHECK (length(btrim(institution)) BETWEEN 1 AND 160),
  department text NOT NULL CHECK (length(btrim(department)) BETWEEN 1 AND 120),
  year_of_study text NOT NULL CHECK (length(btrim(year_of_study)) BETWEEN 1 AND 32),
  interests text[] NOT NULL CHECK (cardinality(interests) BETWEEN 1 AND 4),
  session_id uuid NOT NULL REFERENCES public.aics_sessions(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX aics_registrations_email_unique ON public.aics_registrations (lower(email));
GRANT SELECT ON public.aics_registrations TO authenticated;
GRANT ALL ON public.aics_registrations TO service_role;
ALTER TABLE public.aics_registrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can view student registrations" ON public.aics_registrations FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.create_aics_registration(
  p_full_name text,
  p_email text,
  p_phone text,
  p_institution text,
  p_department text,
  p_year_of_study text,
  p_interests text[],
  p_session_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session_open boolean;
  v_booking_ref text;
BEGIN
  IF p_full_name IS NULL OR length(btrim(p_full_name)) NOT BETWEEN 1 AND 100
     OR p_email IS NULL OR length(btrim(p_email)) NOT BETWEEN 3 AND 255
     OR p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
     OR p_phone IS NULL OR length(btrim(p_phone)) NOT BETWEEN 3 AND 32
     OR p_institution IS NULL OR length(btrim(p_institution)) NOT BETWEEN 1 AND 160
     OR p_department IS NULL OR length(btrim(p_department)) NOT BETWEEN 1 AND 120
     OR p_year_of_study IS NULL OR length(btrim(p_year_of_study)) NOT BETWEEN 1 AND 32
     OR p_interests IS NULL OR cardinality(p_interests) NOT BETWEEN 1 AND 4
     OR NOT (p_interests <@ ARRAY['Web Development', 'Robotics', 'AI Development', 'VFX']::text[])
  THEN
    RAISE EXCEPTION 'Registration details are invalid' USING ERRCODE = '22023';
  END IF;

  SELECT is_open INTO v_session_open
  FROM public.aics_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT v_session_open THEN
    RAISE EXCEPTION 'This session is not currently available' USING ERRCODE = 'P0001';
  END IF;

  v_booking_ref := 'AICS-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  INSERT INTO public.aics_registrations (
    booking_ref, full_name, email, phone, institution, department,
    year_of_study, interests, session_id
  ) VALUES (
    v_booking_ref, btrim(p_full_name), lower(btrim(p_email)), btrim(p_phone),
    btrim(p_institution), btrim(p_department), btrim(p_year_of_study), p_interests, p_session_id
  );
  RETURN v_booking_ref;
END;
$$;
REVOKE ALL ON FUNCTION public.create_aics_registration(text, text, text, text, text, text, text[], uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.create_aics_registration(text, text, text, text, text, text, text[], uuid) TO anon, authenticated, service_role;