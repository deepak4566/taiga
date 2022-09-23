PGDMP  	            
            z           taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.6 |   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    6891187    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    6891311    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            �           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            D           1247    6891664    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            A           1247    6891654    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            1           1255    6891729 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone);
       public          taiga    false            I           1255    6891746 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint);
       public          taiga    false            2           1255    6891730 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb);
       public          taiga    false            �            1259    6891681    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status public.procrastinate_job_status DEFAULT 'todo'::public.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);
 &   DROP TABLE public.procrastinate_jobs;
       public         heap    taiga    false    833    833            3           1255    6891731 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;
 V   DROP FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]);
       public          taiga    false    238            H           1255    6891745 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;
 k   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status);
       public          taiga    false    833            G           1255    6891744 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone);
       public          taiga    false    833            4           1255    6891732 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean);
       public          taiga    false    833            6           1255    6891734    procrastinate_notify_queue()    FUNCTION     
  CREATE FUNCTION public.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.procrastinate_notify_queue();
       public          taiga    false            5           1255    6891733 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;
 a   DROP FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone);
       public          taiga    false            E           1255    6891737 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            C           1255    6891735 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            D           1255    6891736 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_update();
       public          taiga    false            F           1255    6891738 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;
 =   DROP FUNCTION public.procrastinate_unlink_periodic_defers();
       public          taiga    false            �           3602    6891318    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR uint WITH simple;
 7   DROP TEXT SEARCH CONFIGURATION public.simple_unaccent;
       public          taiga    false    2    2    2    2            �            1259    6891271 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    6891269    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    6891280    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    6891278    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    6891264    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    6891262    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    6891241    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id uuid NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    6891239    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    6891232    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    6891230    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    6891190    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    6891188    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    204            �            1259    6891496    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    6891321    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    6891319    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    6891328    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    6891326     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    6891353 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    6891351 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    222            �            1259    6891711    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    836            �            1259    6891709    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    242            �           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    241            �            1259    6891679    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    238            �           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    237            �            1259    6891695    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    6891693 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    240            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    239            �            1259    6891747 3   project_references_7ab756e2409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ab756e2409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ab756e2409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891749 3   project_references_7ac2bd0c409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ac2bd0c409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ac2bd0c409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891751 3   project_references_7ac8ac8a409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ac8ac8a409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ac8ac8a409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891753 3   project_references_7ad08e78409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ad08e78409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ad08e78409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891755 3   project_references_7ad6a1d2409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ad6a1d2409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ad6a1d2409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891757 3   project_references_7adc9556409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7adc9556409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7adc9556409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891759 3   project_references_7ae2492e409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ae2492e409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ae2492e409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891761 3   project_references_7ae7e4c4409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ae7e4c4409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ae7e4c4409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891763 3   project_references_7aed7088409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7aed7088409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7aed7088409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891765 3   project_references_7af31970409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7af31970409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7af31970409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891767 3   project_references_7afa9498409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7afa9498409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7afa9498409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891769 3   project_references_7b01f2f6409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b01f2f6409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b01f2f6409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891771 3   project_references_7b094c4a409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b094c4a409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b094c4a409711edb28b4074e0238e3a;
       public          taiga    false                        1259    6891773 3   project_references_7b10b926409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b10b926409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b10b926409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891775 3   project_references_7b1991ae409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b1991ae409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b1991ae409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891777 3   project_references_7b1f4590409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b1f4590409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b1f4590409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891779 3   project_references_7b25cf96409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b25cf96409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b25cf96409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891781 3   project_references_7b2ef0f8409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b2ef0f8409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b2ef0f8409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891783 3   project_references_7b38d24e409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b38d24e409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b38d24e409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891785 3   project_references_7b43aeee409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7b43aeee409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7b43aeee409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891787 3   project_references_7cfd7972409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7cfd7972409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7cfd7972409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891789 3   project_references_7d025faa409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d025faa409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d025faa409711edb28b4074e0238e3a;
       public          taiga    false            	           1259    6891791 3   project_references_7d07f26c409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d07f26c409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d07f26c409711edb28b4074e0238e3a;
       public          taiga    false            
           1259    6891793 3   project_references_7d5c0cee409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d5c0cee409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d5c0cee409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891795 3   project_references_7d66b32e409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d66b32e409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d66b32e409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891797 3   project_references_7d6def9a409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d6def9a409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d6def9a409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891799 3   project_references_7d7404d4409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d7404d4409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d7404d4409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891801 3   project_references_7d79902a409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d79902a409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d79902a409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891803 3   project_references_7d7ee386409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d7ee386409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d7ee386409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891805 3   project_references_7d8566de409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d8566de409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d8566de409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891807 3   project_references_7d89936c409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d89936c409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d89936c409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891809 3   project_references_7d8ec38c409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d8ec38c409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d8ec38c409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891811 3   project_references_7d94fd38409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d94fd38409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d94fd38409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891813 3   project_references_7d9f88de409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7d9f88de409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7d9f88de409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891815 3   project_references_7da4d7bc409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7da4d7bc409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7da4d7bc409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891817 3   project_references_7db16bf8409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7db16bf8409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7db16bf8409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891819 3   project_references_7db7d1dc409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7db7d1dc409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7db7d1dc409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891821 3   project_references_7dbe6d62409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7dbe6d62409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7dbe6d62409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891823 3   project_references_7dc34120409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7dc34120409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7dc34120409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891825 3   project_references_7dca5a1e409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7dca5a1e409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7dca5a1e409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891827 3   project_references_7dcf9ace409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7dcf9ace409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7dcf9ace409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891829 3   project_references_7dd6fdfa409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7dd6fdfa409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7dd6fdfa409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891831 3   project_references_7de00512409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7de00512409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7de00512409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891833 3   project_references_7dea85be409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7dea85be409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7dea85be409711edb28b4074e0238e3a;
       public          taiga    false                       1259    6891835 3   project_references_7e1c2736409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e1c2736409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e1c2736409711edb28b4074e0238e3a;
       public          taiga    false                        1259    6891837 3   project_references_7e200eb4409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e200eb4409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e200eb4409711edb28b4074e0238e3a;
       public          taiga    false            !           1259    6891839 3   project_references_7e255554409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e255554409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e255554409711edb28b4074e0238e3a;
       public          taiga    false            "           1259    6891841 3   project_references_7e2a947e409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e2a947e409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e2a947e409711edb28b4074e0238e3a;
       public          taiga    false            #           1259    6891843 3   project_references_7e2fb648409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e2fb648409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e2fb648409711edb28b4074e0238e3a;
       public          taiga    false            $           1259    6891845 3   project_references_7e340888409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e340888409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e340888409711edb28b4074e0238e3a;
       public          taiga    false            %           1259    6891847 3   project_references_7e39effa409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e39effa409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e39effa409711edb28b4074e0238e3a;
       public          taiga    false            &           1259    6891849 3   project_references_7e3f1da4409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e3f1da4409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e3f1da4409711edb28b4074e0238e3a;
       public          taiga    false            '           1259    6891851 3   project_references_7e4361de409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e4361de409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e4361de409711edb28b4074e0238e3a;
       public          taiga    false            (           1259    6891853 3   project_references_7e47b284409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e47b284409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e47b284409711edb28b4074e0238e3a;
       public          taiga    false            )           1259    6891855 3   project_references_7ebd5822409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7ebd5822409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7ebd5822409711edb28b4074e0238e3a;
       public          taiga    false            *           1259    6891858 3   project_references_7f16af94409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7f16af94409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7f16af94409711edb28b4074e0238e3a;
       public          taiga    false            +           1259    6891860 3   project_references_7f1e6f4a409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7f1e6f4a409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7f1e6f4a409711edb28b4074e0238e3a;
       public          taiga    false            ,           1259    6891866 3   project_references_83af0f38409711edb28b4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_83af0f38409711edb28b4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_83af0f38409711edb28b4074e0238e3a;
       public          taiga    false            �            1259    6891453 &   projects_invitations_projectinvitation    TABLE     �  CREATE TABLE public.projects_invitations_projectinvitation (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    num_emails_sent integer NOT NULL,
    resent_at timestamp with time zone,
    revoked_at timestamp with time zone,
    invited_by_id uuid,
    project_id uuid NOT NULL,
    resent_by_id uuid,
    revoked_by_id uuid,
    role_id uuid NOT NULL,
    user_id uuid
);
 :   DROP TABLE public.projects_invitations_projectinvitation;
       public         heap    taiga    false            �            1259    6891415 &   projects_memberships_projectmembership    TABLE     �   CREATE TABLE public.projects_memberships_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 :   DROP TABLE public.projects_memberships_projectmembership;
       public         heap    taiga    false            �            1259    6891375    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    slug character varying(250) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    public_permissions text[],
    workspace_member_permissions text[],
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    6891385    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb,
    workflows jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            �            1259    6891397    projects_roles_projectrole    TABLE       CREATE TABLE public.projects_roles_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 .   DROP TABLE public.projects_roles_projectrole;
       public         heap    taiga    false            �            1259    6891538    stories_story    TABLE     J  CREATE TABLE public.stories_story (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    ref bigint NOT NULL,
    title character varying(500) NOT NULL,
    "order" bigint NOT NULL,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL
);
 !   DROP TABLE public.stories_story;
       public         heap    taiga    false            �            1259    6891584    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    6891574    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
    id uuid NOT NULL,
    object_id uuid,
    jti character varying(255) NOT NULL,
    token_type text NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    content_type_id integer
);
 +   DROP TABLE public.tokens_outstandingtoken;
       public         heap    taiga    false            �            1259    6891210    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    6891198 
   users_user    TABLE     �  CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    6891506    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    6891514    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    6891621 *   workspaces_memberships_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 >   DROP TABLE public.workspaces_memberships_workspacemembership;
       public         heap    taiga    false            �            1259    6891603    workspaces_roles_workspacerole    TABLE       CREATE TABLE public.workspaces_roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_roles_workspacerole;
       public         heap    taiga    false            �            1259    6891367    workspaces_workspace    TABLE     T  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false                       2604    6891714    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    241    242    242            �           2604    6891684    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    237    238    238            �           2604    6891698     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    239    240    240            \          0    6891271 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    214   �Y      ^          0    6891280    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    216   �Y      Z          0    6891264    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    212   �Y      X          0    6891241    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    210   �]      V          0    6891232    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    208   �]      R          0    6891190    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    204   �^      k          0    6891496    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    229   na      `          0    6891321    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    218   �a      b          0    6891328    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    220   �a      d          0    6891353 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    222   �a      x          0    6891711    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    242   �a      t          0    6891681    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    238   �a      v          0    6891695    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    240   b      j          0    6891453 &   projects_invitations_projectinvitation 
   TABLE DATA           �   COPY public.projects_invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    228   9b      i          0    6891415 &   projects_memberships_projectmembership 
   TABLE DATA           n   COPY public.projects_memberships_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    227   �k      f          0    6891375    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, slug, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    224   �x      g          0    6891385    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    225   �      h          0    6891397    projects_roles_projectrole 
   TABLE DATA           p   COPY public.projects_roles_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    226   ��      n          0    6891538    stories_story 
   TABLE DATA              COPY public.stories_story (id, created_at, ref, title, "order", created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    232   	�      p          0    6891584    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    234   9      o          0    6891574    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    233   ,9      T          0    6891210    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    206   I9      S          0    6891198 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, date_joined, date_verification) FROM stdin;
    public          taiga    false    205   f9      l          0    6891506    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    230   �B      m          0    6891514    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    231   �E      r          0    6891621 *   workspaces_memberships_workspacemembership 
   TABLE DATA           t   COPY public.workspaces_memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    236   �P      q          0    6891603    workspaces_roles_workspacerole 
   TABLE DATA           v   COPY public.workspaces_roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    235   �X      e          0    6891367    workspaces_workspace 
   TABLE DATA           t   COPY public.workspaces_workspace (id, name, slug, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    223   �\      �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    213            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    215            �           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 92, true);
          public          taiga    false    211            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    209            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 23, true);
          public          taiga    false    207            �           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 35, true);
          public          taiga    false    203            �           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    217            �           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    219            �           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    221            �           0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    241            �           0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    237            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    239            �           0    0 3   project_references_7ab756e2409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ab756e2409711edb28b4074e0238e3a', 19, true);
          public          taiga    false    243            �           0    0 3   project_references_7ac2bd0c409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ac2bd0c409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    244            �           0    0 3   project_references_7ac8ac8a409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ac8ac8a409711edb28b4074e0238e3a', 13, true);
          public          taiga    false    245            �           0    0 3   project_references_7ad08e78409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ad08e78409711edb28b4074e0238e3a', 27, true);
          public          taiga    false    246            �           0    0 3   project_references_7ad6a1d2409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ad6a1d2409711edb28b4074e0238e3a', 29, true);
          public          taiga    false    247            �           0    0 3   project_references_7adc9556409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7adc9556409711edb28b4074e0238e3a', 2, true);
          public          taiga    false    248            �           0    0 3   project_references_7ae2492e409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ae2492e409711edb28b4074e0238e3a', 20, true);
          public          taiga    false    249            �           0    0 3   project_references_7ae7e4c4409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7ae7e4c4409711edb28b4074e0238e3a', 8, true);
          public          taiga    false    250            �           0    0 3   project_references_7aed7088409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7aed7088409711edb28b4074e0238e3a', 11, true);
          public          taiga    false    251            �           0    0 3   project_references_7af31970409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7af31970409711edb28b4074e0238e3a', 6, true);
          public          taiga    false    252            �           0    0 3   project_references_7afa9498409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7afa9498409711edb28b4074e0238e3a', 14, true);
          public          taiga    false    253            �           0    0 3   project_references_7b01f2f6409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7b01f2f6409711edb28b4074e0238e3a', 9, true);
          public          taiga    false    254            �           0    0 3   project_references_7b094c4a409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7b094c4a409711edb28b4074e0238e3a', 8, true);
          public          taiga    false    255            �           0    0 3   project_references_7b10b926409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7b10b926409711edb28b4074e0238e3a', 16, true);
          public          taiga    false    256            �           0    0 3   project_references_7b1991ae409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7b1991ae409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    257            �           0    0 3   project_references_7b1f4590409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7b1f4590409711edb28b4074e0238e3a', 24, true);
          public          taiga    false    258            �           0    0 3   project_references_7b25cf96409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7b25cf96409711edb28b4074e0238e3a', 4, true);
          public          taiga    false    259            �           0    0 3   project_references_7b2ef0f8409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7b2ef0f8409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    260            �           0    0 3   project_references_7b38d24e409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7b38d24e409711edb28b4074e0238e3a', 15, true);
          public          taiga    false    261            �           0    0 3   project_references_7b43aeee409711edb28b4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7b43aeee409711edb28b4074e0238e3a', 4, true);
          public          taiga    false    262            �           0    0 3   project_references_7cfd7972409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7cfd7972409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    263            �           0    0 3   project_references_7d025faa409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d025faa409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    264            �           0    0 3   project_references_7d07f26c409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d07f26c409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    265            �           0    0 3   project_references_7d5c0cee409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d5c0cee409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    266            �           0    0 3   project_references_7d66b32e409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d66b32e409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    267            �           0    0 3   project_references_7d6def9a409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d6def9a409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    268            �           0    0 3   project_references_7d7404d4409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d7404d4409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    269            �           0    0 3   project_references_7d79902a409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d79902a409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    270            �           0    0 3   project_references_7d7ee386409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d7ee386409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    271            �           0    0 3   project_references_7d8566de409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d8566de409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    272            �           0    0 3   project_references_7d89936c409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d89936c409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    273            �           0    0 3   project_references_7d8ec38c409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d8ec38c409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    274            �           0    0 3   project_references_7d94fd38409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d94fd38409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    275            �           0    0 3   project_references_7d9f88de409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7d9f88de409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    276            �           0    0 3   project_references_7da4d7bc409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7da4d7bc409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    277            �           0    0 3   project_references_7db16bf8409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7db16bf8409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    278            �           0    0 3   project_references_7db7d1dc409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7db7d1dc409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    279            �           0    0 3   project_references_7dbe6d62409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7dbe6d62409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    280            �           0    0 3   project_references_7dc34120409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7dc34120409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    281            �           0    0 3   project_references_7dca5a1e409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7dca5a1e409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    282            �           0    0 3   project_references_7dcf9ace409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7dcf9ace409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    283            �           0    0 3   project_references_7dd6fdfa409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7dd6fdfa409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    284            �           0    0 3   project_references_7de00512409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7de00512409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    285            �           0    0 3   project_references_7dea85be409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7dea85be409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    286            �           0    0 3   project_references_7e1c2736409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e1c2736409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    287            �           0    0 3   project_references_7e200eb4409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e200eb4409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    288            �           0    0 3   project_references_7e255554409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e255554409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    289            �           0    0 3   project_references_7e2a947e409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e2a947e409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    290            �           0    0 3   project_references_7e2fb648409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e2fb648409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    291            �           0    0 3   project_references_7e340888409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e340888409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    292            �           0    0 3   project_references_7e39effa409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e39effa409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    293            �           0    0 3   project_references_7e3f1da4409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e3f1da4409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    294            �           0    0 3   project_references_7e4361de409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e4361de409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    295            �           0    0 3   project_references_7e47b284409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7e47b284409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    296            �           0    0 3   project_references_7ebd5822409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7ebd5822409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    297                        0    0 3   project_references_7f16af94409711edb28b4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7f16af94409711edb28b4074e0238e3a', 1, false);
          public          taiga    false    298                       0    0 3   project_references_7f1e6f4a409711edb28b4074e0238e3a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_7f1e6f4a409711edb28b4074e0238e3a', 1000, true);
          public          taiga    false    299                       0    0 3   project_references_83af0f38409711edb28b4074e0238e3a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_83af0f38409711edb28b4074e0238e3a', 2000, true);
          public          taiga    false    300            #           2606    6891309    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    214            (           2606    6891295 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    216    216            +           2606    6891284 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    216            %           2606    6891275    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    214                       2606    6891286 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    212    212                        2606    6891268 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    212                       2606    6891249 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    210                       2606    6891238 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    208    208                       2606    6891236 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    208                       2606    6891197 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    204            o           2606    6891503 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    229            /           2606    6891325 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    218            3           2606    6891336 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    218    218            5           2606    6891334 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    220    220    220            9           2606    6891332 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    220            >           2606    6891359 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    222            @           2606    6891361 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    222            �           2606    6891717 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    242            �           2606    6891692 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    238            �           2606    6891701 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    240            �           2606    6891703 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    240    240    240            d           2606    6891459 ^   projects_invitations_projectinvitation projects_invitations_pro_email_project_id_b147d04b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_pro_email_project_id_b147d04b_uniq UNIQUE (email, project_id);
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_pro_email_project_id_b147d04b_uniq;
       public            taiga    false    228    228            g           2606    6891457 R   projects_invitations_projectinvitation projects_invitations_projectinvitation_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_pkey;
       public            taiga    false    228            ]           2606    6891421 `   projects_memberships_projectmembership projects_memberships_pro_user_id_project_id_fac8390b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_pro_user_id_project_id_fac8390b_uniq UNIQUE (user_id, project_id);
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_pro_user_id_project_id_fac8390b_uniq;
       public            taiga    false    227    227            _           2606    6891419 R   projects_memberships_projectmembership projects_memberships_projectmembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_pkey;
       public            taiga    false    227            K           2606    6891382 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    224            N           2606    6891384 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    224            Q           2606    6891392 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    225            T           2606    6891394 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    225            V           2606    6891404 :   projects_roles_projectrole projects_roles_projectrole_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_pkey;
       public            taiga    false    226            [           2606    6891406 S   projects_roles_projectrole projects_roles_projectrole_slug_project_id_ef23bf22_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_slug_project_id_ef23bf22_uniq UNIQUE (slug, project_id);
 }   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_slug_project_id_ef23bf22_uniq;
       public            taiga    false    226    226            ~           2606    6891545     stories_story stories_story_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_pkey;
       public            taiga    false    232            �           2606    6891548 8   stories_story stories_story_ref_project_id_ccca2722_uniq 
   CONSTRAINT     ~   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_ref_project_id_ccca2722_uniq UNIQUE (ref, project_id);
 b   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_ref_project_id_ccca2722_uniq;
       public            taiga    false    232    232            �           2606    6891588 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    234            �           2606    6891590 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    234            �           2606    6891583 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    233            �           2606    6891581 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    233                       2606    6891221 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    206    206                       2606    6891217 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    206                       2606    6891209    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    205            	           2606    6891205    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    205                       2606    6891207 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    205            r           2606    6891513 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    230            u           2606    6891523 C   workflows_workflow workflows_workflow_slug_project_id_80394f0d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq UNIQUE (slug, project_id);
 m   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq;
       public            taiga    false    230    230            w           2606    6891521 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    231            y           2606    6891531 P   workflows_workflowstatus workflows_workflowstatus_slug_workflow_id_06486b8e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq UNIQUE (slug, workflow_id);
 z   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq;
       public            taiga    false    231    231            �           2606    6891627 f   workspaces_memberships_workspacemembership workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq;
       public            taiga    false    236    236            �           2606    6891625 Z   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_pkey;
       public            taiga    false    236            �           2606    6891610 B   workspaces_roles_workspacerole workspaces_roles_workspacerole_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_pkey;
       public            taiga    false    235            �           2606    6891612 ]   workspaces_roles_workspacerole workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq UNIQUE (slug, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq;
       public            taiga    false    235    235            D           2606    6891371 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    223            G           2606    6891373 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    223            !           1259    6891310    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    214            &           1259    6891306 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    216            )           1259    6891307 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    216                       1259    6891292 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    212                       1259    6891260 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    210                       1259    6891261 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    210            m           1259    6891505 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    229            p           1259    6891504 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    229            ,           1259    6891339 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    218            -           1259    6891340 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    218            0           1259    6891337 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    218            1           1259    6891338 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    218            6           1259    6891348 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    220            7           1259    6891349 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    220            :           1259    6891350 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    220            ;           1259    6891346 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    220            <           1259    6891347 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    220            �           1259    6891727     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    242            �           1259    6891726    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    833    238    238    238            �           1259    6891724    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    833    238    238            �           1259    6891725 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    238            �           1259    6891723 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    238    238    833            �           1259    6891728 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    240            e           1259    6891490 =   projects_invitations_projectinvitation_invited_by_id_e41218dc    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_invited_by_id_e41218dc ON public.projects_invitations_projectinvitation USING btree (invited_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_invited_by_id_e41218dc;
       public            taiga    false    228            h           1259    6891491 :   projects_invitations_projectinvitation_project_id_8a729cae    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_project_id_8a729cae ON public.projects_invitations_projectinvitation USING btree (project_id);
 N   DROP INDEX public.projects_invitations_projectinvitation_project_id_8a729cae;
       public            taiga    false    228            i           1259    6891492 <   projects_invitations_projectinvitation_resent_by_id_68c580e8    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_resent_by_id_68c580e8 ON public.projects_invitations_projectinvitation USING btree (resent_by_id);
 P   DROP INDEX public.projects_invitations_projectinvitation_resent_by_id_68c580e8;
       public            taiga    false    228            j           1259    6891493 =   projects_invitations_projectinvitation_revoked_by_id_8a8e629a    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_revoked_by_id_8a8e629a ON public.projects_invitations_projectinvitation USING btree (revoked_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_revoked_by_id_8a8e629a;
       public            taiga    false    228            k           1259    6891494 7   projects_invitations_projectinvitation_role_id_bb735b0e    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_role_id_bb735b0e ON public.projects_invitations_projectinvitation USING btree (role_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_role_id_bb735b0e;
       public            taiga    false    228            l           1259    6891495 7   projects_invitations_projectinvitation_user_id_995e9b1c    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_user_id_995e9b1c ON public.projects_invitations_projectinvitation USING btree (user_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_user_id_995e9b1c;
       public            taiga    false    228            `           1259    6891437 :   projects_memberships_projectmembership_project_id_7592284f    INDEX     �   CREATE INDEX projects_memberships_projectmembership_project_id_7592284f ON public.projects_memberships_projectmembership USING btree (project_id);
 N   DROP INDEX public.projects_memberships_projectmembership_project_id_7592284f;
       public            taiga    false    227            a           1259    6891438 7   projects_memberships_projectmembership_role_id_43773f6c    INDEX     �   CREATE INDEX projects_memberships_projectmembership_role_id_43773f6c ON public.projects_memberships_projectmembership USING btree (role_id);
 K   DROP INDEX public.projects_memberships_projectmembership_role_id_43773f6c;
       public            taiga    false    227            b           1259    6891439 7   projects_memberships_projectmembership_user_id_8a613b51    INDEX     �   CREATE INDEX projects_memberships_projectmembership_user_id_8a613b51 ON public.projects_memberships_projectmembership USING btree (user_id);
 K   DROP INDEX public.projects_memberships_projectmembership_user_id_8a613b51;
       public            taiga    false    227            H           1259    6891451 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    224    224            I           1259    6891445 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    224            L           1259    6891395 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    224            O           1259    6891452 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    224            R           1259    6891396 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    225            W           1259    6891414 .   projects_roles_projectrole_project_id_4efc0342    INDEX     {   CREATE INDEX projects_roles_projectrole_project_id_4efc0342 ON public.projects_roles_projectrole USING btree (project_id);
 B   DROP INDEX public.projects_roles_projectrole_project_id_4efc0342;
       public            taiga    false    226            X           1259    6891412 (   projects_roles_projectrole_slug_9eb663ce    INDEX     o   CREATE INDEX projects_roles_projectrole_slug_9eb663ce ON public.projects_roles_projectrole USING btree (slug);
 <   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce;
       public            taiga    false    226            Y           1259    6891413 -   projects_roles_projectrole_slug_9eb663ce_like    INDEX     �   CREATE INDEX projects_roles_projectrole_slug_9eb663ce_like ON public.projects_roles_projectrole USING btree (slug varchar_pattern_ops);
 A   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce_like;
       public            taiga    false    226            {           1259    6891546    stories_sto_project_840ba5_idx    INDEX     c   CREATE INDEX stories_sto_project_840ba5_idx ON public.stories_story USING btree (project_id, ref);
 2   DROP INDEX public.stories_sto_project_840ba5_idx;
       public            taiga    false    232    232            |           1259    6891570 $   stories_story_created_by_id_052bf6c8    INDEX     g   CREATE INDEX stories_story_created_by_id_052bf6c8 ON public.stories_story USING btree (created_by_id);
 8   DROP INDEX public.stories_story_created_by_id_052bf6c8;
       public            taiga    false    232                       1259    6891571 !   stories_story_project_id_c78d9ba8    INDEX     a   CREATE INDEX stories_story_project_id_c78d9ba8 ON public.stories_story USING btree (project_id);
 5   DROP INDEX public.stories_story_project_id_c78d9ba8;
       public            taiga    false    232            �           1259    6891569    stories_story_ref_07544f5a    INDEX     S   CREATE INDEX stories_story_ref_07544f5a ON public.stories_story USING btree (ref);
 .   DROP INDEX public.stories_story_ref_07544f5a;
       public            taiga    false    232            �           1259    6891572     stories_story_status_id_15c8b6c9    INDEX     _   CREATE INDEX stories_story_status_id_15c8b6c9 ON public.stories_story USING btree (status_id);
 4   DROP INDEX public.stories_story_status_id_15c8b6c9;
       public            taiga    false    232            �           1259    6891573 "   stories_story_workflow_id_448ab642    INDEX     c   CREATE INDEX stories_story_workflow_id_448ab642 ON public.stories_story USING btree (workflow_id);
 6   DROP INDEX public.stories_story_workflow_id_448ab642;
       public            taiga    false    232            �           1259    6891597 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    233            �           1259    6891596 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    233                       1259    6891227    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    206                       1259    6891228     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    206                       1259    6891229    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    206                       1259    6891219    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    205            
           1259    6891218 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    205            s           1259    6891529 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    230            z           1259    6891537 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    231            �           1259    6891645 0   workspaces_memberships_wor_workspace_id_fd6f07d4    INDEX     �   CREATE INDEX workspaces_memberships_wor_workspace_id_fd6f07d4 ON public.workspaces_memberships_workspacemembership USING btree (workspace_id);
 D   DROP INDEX public.workspaces_memberships_wor_workspace_id_fd6f07d4;
       public            taiga    false    236            �           1259    6891643 ;   workspaces_memberships_workspacemembership_role_id_4ea4e76e    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_role_id_4ea4e76e ON public.workspaces_memberships_workspacemembership USING btree (role_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_role_id_4ea4e76e;
       public            taiga    false    236            �           1259    6891644 ;   workspaces_memberships_workspacemembership_user_id_89b29e02    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_user_id_89b29e02 ON public.workspaces_memberships_workspacemembership USING btree (user_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_user_id_89b29e02;
       public            taiga    false    236            �           1259    6891618 ,   workspaces_roles_workspacerole_slug_6d21c03e    INDEX     w   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e ON public.workspaces_roles_workspacerole USING btree (slug);
 @   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e;
       public            taiga    false    235            �           1259    6891619 1   workspaces_roles_workspacerole_slug_6d21c03e_like    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e_like ON public.workspaces_roles_workspacerole USING btree (slug varchar_pattern_ops);
 E   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e_like;
       public            taiga    false    235            �           1259    6891620 4   workspaces_roles_workspacerole_workspace_id_1aebcc14    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_workspace_id_1aebcc14 ON public.workspaces_roles_workspacerole USING btree (workspace_id);
 H   DROP INDEX public.workspaces_roles_workspacerole_workspace_id_1aebcc14;
       public            taiga    false    235            A           1259    6891651 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    223    223            B           1259    6891652 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    223            E           1259    6891374 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    223            �           2620    6891739 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    833    310    238    238            �           2620    6891743 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    326    238            �           2620    6891742 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    238    238    238    325    833            �           2620    6891741 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    238    323    238    833            �           2620    6891740 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    238    324    238            �           2606    6891301 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    212    3104    216            �           2606    6891296 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    3109    214    216            �           2606    6891287 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    3095    208    212            �           2606    6891250 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    210    208    3095            �           2606    6891255 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    3081    210    205            �           2606    6891341 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    220    3119    218            �           2606    6891362 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    220    3129    222            �           2606    6891718 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    238    3232    242            �           2606    6891704 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    238    3232    240            �           2606    6891460 _   projects_invitations_projectinvitation projects_invitations_invited_by_id_e41218dc_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use;
       public          taiga    false    228    205    3081            �           2606    6891465 \   projects_invitations_projectinvitation projects_invitations_project_id_8a729cae_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_;
       public          taiga    false    228    224    3147            �           2606    6891470 ^   projects_invitations_projectinvitation projects_invitations_resent_by_id_68c580e8_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use;
       public          taiga    false    3081    228    205            �           2606    6891475 _   projects_invitations_projectinvitation projects_invitations_revoked_by_id_8a8e629a_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use;
       public          taiga    false    3081    228    205            �           2606    6891480 Y   projects_invitations_projectinvitation projects_invitations_role_id_bb735b0e_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_;
       public          taiga    false    228    3158    226            �           2606    6891485 Y   projects_invitations_projectinvitation projects_invitations_user_id_995e9b1c_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use;
       public          taiga    false    3081    228    205            �           2606    6891422 \   projects_memberships_projectmembership projects_memberships_project_id_7592284f_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_;
       public          taiga    false    3147    227    224            �           2606    6891427 Y   projects_memberships_projectmembership projects_memberships_role_id_43773f6c_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_;
       public          taiga    false    3158    227    226            �           2606    6891432 Y   projects_memberships_projectmembership projects_memberships_user_id_8a613b51_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use;
       public          taiga    false    3081    227    205            �           2606    6891440 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    3081    224    205            �           2606    6891446 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    224    3140    223            �           2606    6891407 P   projects_roles_projectrole projects_roles_proje_project_id_4efc0342_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_;
       public          taiga    false    226    224    3147            �           2606    6891549 C   stories_story stories_story_created_by_id_052bf6c8_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id;
       public          taiga    false    205    232    3081            �           2606    6891554 F   stories_story stories_story_project_id_c78d9ba8_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id;
       public          taiga    false    224    232    3147            �           2606    6891559 M   stories_story stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id;
       public          taiga    false    231    3191    232            �           2606    6891564 I   stories_story stories_story_workflow_id_448ab642_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id;
       public          taiga    false    3186    232    230            �           2606    6891598 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    233    3210    234            �           2606    6891591 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    208    3095    233            �           2606    6891222 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    3081    206    205            �           2606    6891524 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    3147    224    230            �           2606    6891532 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    3186    231    230            �           2606    6891628 ]   workspaces_memberships_workspacemembership workspaces_membershi_role_id_4ea4e76e_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace;
       public          taiga    false    236    3216    235            �           2606    6891633 ]   workspaces_memberships_workspacemembership workspaces_membershi_user_id_89b29e02_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use;
       public          taiga    false    236    3081    205            �           2606    6891638 b   workspaces_memberships_workspacemembership workspaces_membershi_workspace_id_fd6f07d4_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace;
       public          taiga    false    223    3140    236            �           2606    6891613 V   workspaces_roles_workspacerole workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace;
       public          taiga    false    3140    223    235            �           2606    6891646 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    223    205    3081            \      xڋ���� � �      ^      xڋ���� � �      Z   �  x�u�[��0E��U���ś�l#U)�(\�gjv�Zt���7H��%� F�짬��:O���l�zZeԾ����;���O7�~���{�[��U����gk�N�]㺎�r����Y�6ԕ�`J�E�4	ם��e~=U����\�\�/@u
� ��J �l��}�e��[�T�,�kw�MIE(2HVԇ���d�Z�sjH5��j�=��\i�R5d@��:�X,��BN�D�i�9/��g���>�첾�OU;�swt�F�0x�y6+�䡐�'��M�5���z��V5�ﱦ�Zn
����4r;�Ľ|��A�w�|��P-/���(�s��.�輣��.rAu��.p����^�l�>ƭߎG����u]����4K�lb�l8��,�a1�O�4�$-�c�{�&y�V�ɓ�'wRO�EI���Ey�6�A�4u��1��{8�\jh��
�Q�.>P�-N�=\����TZ�� |@�U���yp\Q�m�wP�L�]r?7�x��moQP�����t_i��b�H��y��}�1�C;����Oe��l:�uU�GS�����*>�IN&O��`
�y0y�I�u��תL�$���ZI�d"��$o��!V_�$ĺ�N�k��2��}��k6�a�=�f/ �	2la�y�]�����gC����w�p\���Q6c)Dɘ1��!���n��if���]��	��.ϰ�9����2*'ῷ�>N�����i�[���줌���6&bD�(�1
�i��t��N�`����nv�P�߄�6[R
�%A6]R����̗sՒN�:���s'�o=�[6e���(6iH��(2m��	�����x���r�F;t�F���EX6s�9�c�S$\�Zf�����U��-�]D�(��?`�>�����B�(����Z���J��      X      xڋ���� � �      V     x�u��n�0D��SŐ�TBނ|�w݈��!��Ҿ����V��;F�<�� �P�{0ZCd����tѧ G��5N��'�'A8�hpOT��X�w�ԛ@�.&\����զ��B�p!�ol��~+��X ���Y�����"YƙCV[�
����hà8��3�����)��?\ʨ�@�E��2?A^�iھV�@^��&�M��M�`�m�8_�q��@uX#�n1�%����ޝ2C�ͧ�WZUo�&������K���� ~9�݆      R   �  xڕ��r�0���S����v��g�F�[ *��}�p��؁�x������
��w��!`|듷u���J~���QP`��$d��6�ɵ)�:�F�$�JZ�]��%)�Q�.4u��c��Dׄ�3vH����6C3!����0���m�5/�ݛ�!�m��K��� �4�՜��im�n��)(Y���fH�+ΫY����Eӹ����O4�}7�k����(�8��g=���X_/Q!�t��v�J=�K��̹(���Q�>��򹵡�m���.�)"����<�2*3�v"9/��!�\���~gS�}	��1DӸ���;YQH-6��Mw�|VL�=�3I�hJ#GVP����0t�0:�U���0C�-r����t��C��f6��W���SZ�q���y�[�Ȥ�����O&��ͩ_�ɴ&Bn������3A=�Dh(�#Vo!����./�,DIiqi����i�L(6md���P�9���I�_čk���q���R�Ń�S���L�����ߪ�p6}7�.����Me$��"�dA�w�8/ˤ YN�����o+tT"L7$T}^6~�X�"�aX����Tȥ�S�)�
��(F�?ʮ��	$_���	��q���_����/d�^�      k      xڋ���� � �      `      xڋ���� � �      b      xڋ���� � �      d      xڋ���� � �      x      xڋ���� � �      t      xڋ���� � �      v      xڋ���� � �      j   L	  x�͝�n$���=O���EQ�W��s��b�����G*'@��t�lT�=0��ğ?EIN�Zh��	$�;��;����D�s����8���������/���Z����������/�?8������W�7��������G��)�|�))�bǇ�����E�I<x�PzO?�K*ԝ�|ȏg�=��>������s<��.�Cz��o�ߤ�#����C|:��������|Ԉ���>���R��[����~��z��\�r��x|���?��O7P��D!�~@_��g����}l��/m�=�qڗS�n��I"
�s
�?���o{��?�o����m�~����K����O�m������)?W�4�*�J\G�H�)�&�q=�=�����Nq��q��9� _�S�9�s)�QXOzB�jz_b���)OY�'k�#�����J��{��P��������7�Tu氋��q=0�o[�� ��z�L�ЪO��j|���|>����jh�>�`�u^�KA˜>��u�%����~$w�ӝZՙ������.z�����9���)"_ehx�T˜6�.�-���@U=����k��V�5,P�BՅ#���,7�W��̯RU}��o��Ruiu@>���(�'}"w=�n�Yf�:�.�Mz�WÓg�HiՍ�z����!�]�����k�姖J2�G�-[��?�����uj�s��a�q��-�%ï�9V�G��]��/����u�*�ૡ����:�SQ#C?��_>�7?�;�Y`��$>=Wef\��W����T2��ṱ�����>"�h���Ề7�WU��77�,�7|��b�6ӵ"���Wl9��cq�����|�$�UpݧYaZD���Ȗ�=���u�=��n�����_�_�M�:*;`�Ȟ��r��չ*���b�A�?5�S�J:8�\�A)V��	��
l�Bt|M[i��ЬY�0���|n�R�:����O|箧W����J�[�j^n0���^]
�P�'=�ty�o���w�&��ke�8��#��[_�}�%����_�GC�:����us����Im�p|URC���,�'~���%�_%����m�G¶���/���W��Ys�����;�WЫ�J�~@!ì6���S�j�GD2,UB����N��7hj��>��e��iR_�!\ϯK�>C#ˬ��o0����s������#��U����n��'~H���|�1W��&~�z��/����4�FQ4��~Bw|���K醝��O7�}Ug�p�j�P���y_U��hX�&	a7�
ZLYHt�nT�2��疢eڟ���z/�O-��}�{�~	ѻ�G_'�TJ���ܢ�|��W��@��s_���[9�-���ދ���8T��]�8�UCƐ�a�e�˫�}�~e�����XO��M�IO��5�N�Bnd;K���5�W���f1Wum�?�k������j��k2=g����I��X�R���V��]�I��R�3�o��+�b�Ǝ�`�� ��>q�8��&�eWu������v
3_��a����:EP'[#z�0,)B�v��7|�{��}��K�l��6���x�ʯ��J�;�������)[b�jw_І��o��Z�K������w�]��	��z�v�Ļ���a=���]G�;ar��l�m×]k�|���hw��'��3�/8��EpUR+��X����5�*a&��;CO�S_��@8wCY_�����������ؼ�Y�=�6(��mT�I*d2�ۈ �C��#]��9�����srz8w�RYu#�:��v��x�'u��kamTM*����nd���p��^eF��f�|>�w;���Wu�J��8���o��*��@��ЊN��i�K�uV���fv�7|�A�떎+���ݝ��;a��W-�T���ݝ_`����<w�j���H�vm�t}��M���9�8������jC�R�����-ח?��C�M���S��K�~����oPKv=:�E�۹|���Ma�H��n�]?�u�n�3�>{w��+�zCp`hh~�7�W�ڤ04�_�0�*C�@H��k݂�t��WU�z����-|���o����H���K4�vn��\�'憤[8^g���U�0t4w��z��i���o�B7������2(��/�j�|��k�U���n�˫G?7�&w�4viX�D	n�:?׸p�\���n�ׅ���9�Ҳ�.�������)��j�l/�.�OKӠ&6�)N8ﮟ�\�k�z���vG(ul��}*6
=��]����{���U��9�,O�Uc|]޻� ��=�]�W㳧l!�et˭�/������������ ���˗/��`      i   �  xڵ�K�9��Ǖ��y��HQYk鉞�_B3��I�z�exb#p������K풩������?*J�f��X���G�1�O�� ��'HT���_�Ԝx�?�R�??�5h��C�'M�Ή�";�T��k`���Ěc��Ĥ��-����sB\`B[��qi�Kbn(�����K������=]�CBI��H�x���U� �J୊ѸCY��1��M<gж&�n������F]c���8��c��yE�J�Ή	�#�"nX{X��Q�<<B^˚K� V�3bis��8O�Yy	�3�f����'23{�E�i\�X���M��+� �K���b�/oz���b�G�I"�D�YR8τb�$�M��� � N��{έS-��UĘ�߄�Y�)J�Xx=�X/DA�1�P�c��4y��%#��[�3e����R����v.�RM������Z���JM�<��L���xo�U�ES��w��G��l����b5�#�Yz4Xzm�\�X0x�y���.t,��W��QΝA���4�U{�w�u���	�8����������>0.�U��ߍx/�Y�!B�m�*op�EtNL�k�a��
��L��ar��S"�R7?�=�zCly���7u�EC� �xDܚO�6*6�Xy��u�#j�y�,.2n0�B"�ٙxS-S� 6�o��D�q��O�5Jsi���'���[����� �@����9����S\T1�i<w��;#67��'B�bAo�
d"�p�&L����L���&��7�H�x+���k=��RҘެbF�e9Iʲ鶷�rG8�*'�:�n�{e�b��o��@6�M�.���,���)���M���d��-e�_�v#�y<�1��*��ͩR��>��b�.�:��� 6��7�V2KT����y{:WY�{����b�lЋ��cA���c��;��x� �qC��k�o�F���X�T�;{��z�5�L������'�C�a.2����ę���x+u3�.R7��O�)ª.�J�j�\ټ1~�j�tY�,��U���fƈY��{��W!�y�b�xϷAj�^ 3�wV�޹*�dl�豣P!Ǥ�U^��M�8o-<ȕ.�s&�37S��*$�Ē�7�Vvl�-���8� �6�
 ��|�
��y�h� �E"��A�$�P�J'��ぱ�1˻��H��+FVĢ*��{�����B�[�mW���B�g��|������?���&�C�Xz����HӯV�����O��i��ᏱQ�vA�Y��\����q��
��8�3�;��t�B�w����[��2��ؼ��������c��O�&�i���4�_q$�J�b��wa�$�۹�������K���汲dL�ě6Nu�+�G�l鱻��������3�Cș=�qdm����g�2/f�)�TB��m�$�</��T"$o� ����*I՛x/���Š��dq'�
yq�q\����~��tGZU �t)�ŹM]��Hٛx/�Xv0�g�b�O�{���t9�oĹ�W��0�7� ��>�C�1Eo�-wl��pA����x�!�]�q�w�ؑx����8c���[��"�^ؘy�x+�'��/��k�ޘ�3Ƕ ~�N�?�(皀@��49�ٸ�tA����x$�Q���yC��}�#�+@�"H� �Y�g�����N�Aj�f�o���n~n��,��58��&8��1�����<�Ls���{Ar!�\�8'~&��%���=�Ľ��6N7�bN���oy�N�P���"�I�*��A�Xf�s����pdc��5�x�zC�����mZ���q�LΚت�X��~���,o�I\�u��ɈG����a>t&ު?:'.��X#~f߈�Sm�;�ȋFY�`�X[��9=W?b�PZ�(�k\�x�:~����޹F\��2��9o��S�$� �}�=?�w���߅�����2_�S�q�t�3Szϸ�L��jM�Ta56�I<R�sW!�;~��ǥ�+��n�MU��1��X�A7{�e#a���$���o�g���R`�&�E.�Y�#�ī�[�!6]����Bѹ�xj�wLa���.�صq��u��%�ņ�L+����Fߴ�v��x�h�%��a��ω1<��j��?�Ѣ��5�,\l�$��� �q��E�Z���r{����g��_��0���Њ���
�ٲ�q�e�޲q!��טFx�@����Yz�����E�^����Yְ�q����n�H�6V�FLw�ǌ.+�r>15b�ớ�W��D�5&.���a9�b&�#�Z�K�Y{(���!�{��^�C_��j��>�S�\��J'�]Tѐ���I���z�<��[x�X.��&���-�*64*T��G� (���$�]d�,y;nW��h:淳�J*ˬ�U�å�kϩ
� ��5�7�[�A���ƝJ�,>O-�������;�0�9���sn��jq�q�*���|u�y���y���c�ju�����$�V�����]t�(�w;z!��a�>�iw)Aä�gut�`Ķ���4qﭞ�8Ř��tI��������hP�����n������
�|�	x��>1���Wm���]m>$�p�b�_�6����:-{���n[x��6V��{m&��$� �]�����A�� ��Ei����L��<ČI��XRZ=��?6q�Y���S��K<+�Ոa�e!�e��s�
N���~r1���S�π�;T1�s�ђ8Q�./*�� ��3b���L�6���9qRxK&{�1W�ۈ����8�^��s�pD����1!󸰱i�snq��R�qC��s�q����s��wm��4ê�=�r�.i�U-����T�.q��b�FΉ)Z��?{�KUH��VP-��b� '���랍��:�1�f���j(ɪ�6��J�5�(�".!� �]��:������j<���g�n��e���f>�)��2��"�z����-��#�1�*��Uc�c'��1���K<x��xL[����ѕ�8���L�5xl��n����#♖����
��c?����\n���	u5���
����͉$�*�W�v$�Q�}�� &�#b���&�t�!�����$��~�������¯AO��S�I��\Ș�;��w�u?�C����=�7�퓄���['��z|�郛����4�^�Pd�0p�_5�'��9�����_��i�      f      x��\Yw�Hv~f�
��K�}�7wϒI2=���3/9'��FB	 E�9��R"e��ӚؖM�^¬�n߭��Q:q"�3�����㥑�ra����e�i�u��a�_��R�HOr�����84|��)50�j� V�mڮ�7(��P�hnl���sB���w����&5w�_(��
n�����1�S發:
:9j�5�o�#W��}��=���rۭ�O�k��mR���PwaW��B�-�ENZ$�Z�<�2U����:�o|��ڻ�[q�nݭ�i�)@r�)\��:A�09�5�3�9�\�,dL$���Y�6���*�o�I��T�7#m�d��!m˟�O�����..+�C�&M�A��6��P?��ag%r�D.�ȧ�U4��v����\.��Ki�|����g�YV/�q�uN�_G#�$t(����!8>L�A�M�'/~l��O\Lk�D��!m�~�M���ui�}R#/��K5�Va߭?��O]�,�G0*���H�~;8R���X���?��В��V�6a�a"���)��B�\j��Y�����ſ���n�C��&=��j�BWu)�]�Vm������P�1>J��*� ��J'��P�)u�I�5CM�
6�Ԡ/��{�"����&e������"�L�<)�ʝ�����fhU��~��0"�54�M��.ƴA��.�@b�9���Y��Ԙn#�MRX�h��Rt�����^q�=�����%̉A�Ly��WR���*;i��v�X%g]8q��U�-~>���АҧM_c�C�!�����"_h����� �C��j��u����W���C~Ֆ���n�F=��;T}(�4w�z��K��4SX�v�X��#�9,��0��I2\/X���(E"�a�#��d��4z<�tӤ��ǗZ�B�<k��Vk��?�->�+z���]���XO�S��:R�.���CDf6͏�?%�5��̲�C-�����G���#} �&l��o�SE���]ꐳ9됔�GK햀~:2�1y.��"�z�1y����)����`%$댍LX����Ap����QbM��NǼt�$�(�����'���Y0g���_A��T�zۤ5���E��QJ^J�]�b=,>4M��j�ɴ$�^��i��;C���h����o�5f�U�.�J����C;�۬�IG�l �E���a�L\c��.�$��5!9K�1���-���\OY�H�|�%2�8W38�����̑���d"�����v��џKSX��t�I�,�:�~�!��n�_/>l��P�#��D�����(!ɪ��zX'���x6�Z�xk��]A=c��ˤWA&|I%����ARnA��J"���	��\N� ���M�ps&�,`Wr���̯�Ň�P:�X� +Q�5&��OHe�����YN.���ç^/>x�ZdiSc��G�m�-��"�ۤ��n��"�`��X!jd&��&4X��d{U�V�B�8�s:,{ן��
J�[|Wǧ�j���ݧ.������H�v�Uշ�N�a��b�
:�=E*/;K�R*=�YbnIzn�z7C�~�Zd8h��ٍ	�-U�ѩYē�B��
�,!-a�7L�����rƸ�>�2%� UB�u��-:R*(]`^].�Ut���ͧ�+R�+��&e:��s�S�_6��J�!�����M�G"�L�g�{� ����~��+
�X�W	#���8T�����ݧ�-W_Va<7c+:���ی�x.Of,O�F͒R6jcv�B�9%Lv�J���H�1�FL��j�h?����H����(��Q�0g!^�9el��+ڶ2%ҡ�N�I;�"�4�����)��r��{�nߵ��k�u� ��n�� ���SAַ�6g����:Q��f�t�T3���Vc^�༓X{��!hmS@B0���)�Q��x;�.D>��<��쮧�?o6���ֹ!�[ߴ����YL����{���w!��K�B��։�mS
����m����H_��t��8"�AB�CsI~���3�9#aB�SB<Q�����L���1d�}[�	��"�ڶ�ն\l�nX�T�~���GB������dk�u�]�C��y;�!�K��F.�[��O��n��C
+<N�}6�|��G.�H���U\�t˄���N[h��]��.��a�w7��2��:`�ڧ&W���xk�|{�l8���u�ӎ&��b�g�)�l�ǽQ<F�1�7<�26�p�N�y);�oQ�b��O�����QQ) ��V��k�X���
��Y�B��ݤ�Г�Ԝ��('�#�m��_��G���2υl�\]�(T�.k��#����\��)��7c��>8��
�RPYr2	!�Y�1$�B��P����Q*�z;���	���qff-j����4K�����}�E�GNQ�f�n+X�U��̟��iJ��j���}��G�>̔�,#�T�P�
��S��ч�֖��l�b�w�~��&����)�P��q�.�n�I�M��[(�	j�ci:�F}iT�`���u���['ʃ���C����LA���6�!�.�E��p�(k^��������/No_��9��X^���1����1�vS��6�_��+ҕ+Ү�q-?��)֪�e����
e�;���Ҡ1�b�ݶ�B
V�M�R�����Y�e��_��	
$R�eB�샧�Z#sp��h5�Y.f������-���*�0�c�w�Zs�r2�էqr�QJ+�q]o��N�X�u�Ӻ��Va�d��B��R���S)(�H���<&c�!�u�i�
e��3��n=e��)�]��FF3^Q�D̠��|=>��ɣ���^����Fu�d.Z,S|(��������FR�$v�,��V�\*	�	,I^awec�M#���n
Q�����)���Dň� u��ݴ��o�}zُh�v���r�mi`)�TR%B���1HlR:"~B�� ��%����-E�%�}Y�xYl�'J�Q�{d�7d����YI�R��_����@�Ҳ^���2�#l���R��J�e�Qy��d��]D��LJr�j��F��10�*�;���z.x�1�����W��*� =�i/���'�g� ;��VG��)����df"@�u�Ō��pVk!*NRI����H�'!Fﺜ��۹-&��5%a����"(�
�z� cM��;h֯�Vb�ՑYj��7J���V��ˁ���6��~�ځ���+��dL�|�`�3��b��<pK�~��?�r�fb���b�N�z�mS��w�;r�R��&f_�c��G���}�d�¾r��>�S�[v�y���|�Ty��Ir�>cS(��V��ө�-�w�<3�b�HU�S% �Pi`:Ybµl�?�2�$��8�H���9#�|���o�����"X�L��nңTq�f �wanQ?��ƇY Fj^>ٖ��կ��_�?le�TIA������+�ʫ��L��9d�G�~"yh�"�WWҧ(���В�@Z)�SQ ���B��[�r
�Y��_J@�&Jpe�/��#��؇�)�T�=QC!�9��aqֹ��\��Ͳc���I�w��q��sF6l����A �1N����VX���M��F:mAi']��
z�;m&ѳ�R�fF�:����7ڎ�=�$}l���9�)�EI�?nu���cRd+��Q{@���{1����y��#uF\!O���L��DǱcV���W��d���:vxR�������<�ʴ�$<V;����l�4J5�ٓ>���۝o��EH���QHNB���S����H�5���(�����<|���ɹ�>��¶���܏��
P.3)#��+��>k�-ge�/���Kᣤ<��mlO�_�
����f��3��dٕ�Z�M�O&;��WL��Y��J_���{����0�]5gˋ��I�3&�!��%BiY���x�9�Yi&/Qs³�~�������'�c�ܭ��ߞ>ƨLv�紕�'����U�N�+����\�["Q��L���KK�0��]�xi�g�� �  �����ZB_�cic�M�H�b,�"��Pj0�k�Pd9��a���Fe=�BO'3)����3%�?`���s�;�U~.��7�ֽڴ�-�C��2����e&R��j�|�H�5�X���,��	�?7��r�k��^PB��:��0�}��L��.�:�&������7��l�w�Ĥ�_��;X�}��/�կl�|V%�����0n�ێ�nƽѫ������vۛꗲȹo7����q�s�rrA&�8Y/n5Ɠ"�@ڐ�T1Z�NT�'�Q҃�����)���ô��p\�)#��\�)[7w�"1��3����e������^��I@S��	�5�E��� �D,��W��ۦ9J�v_��[K�͒h�]�F�6��%��pS}?n��࡭�ž̘��T�1��m����B(���ٕ��¸n%o3��� j�%GN��V9�{A��J���+�Se�W6�$k��MK�'#�:��}��$v�0g>�����7���r�����y�Y+��>4���e���-�.�1\F���P��Hi�U���:��_FEs�>ZN�C�yF*��g
R&��[��[���4�ؐ�i"�
E�o�-5��p��n��#$�V���o*�6�SHۓ
�\�<��ܮ��a������1�U�4��D��ԥ�|?������g���9k�w��2���>W���s�\G�rat���,�-;i!��o7�j�&$������~*��~����4���qwVyy��|�x�=�,�شmW��p�5?n�-�`7�����b�Ԗ��c�J�g�_nR��nA��;�J��ZHL%�D�!����P(
�,b'��hC'�\�P����(��u��<t	��8�e.�u:�EV��Eg�}Z�-[yOQ��S�k!V��z��0�;1��C��N���g��Ϗ|~y�vhۦO��>�<E{�$�r�-~J�&�r�3vS�f�6�/Ǜ/R�f�5+��99��!p."�D���E9�%)rC��`�K�`�L�Y��P����Z=J�z'�3� _w�f<�9&,y��p>~s!'g9Q���/�^g�+� �B�_rɜo�m�#�);�G�s�WY�D��L\k�(~6������[��9'Ř*E*���Y[��4�@�+�k3��v�
�>�K�����O	�#?~!	���Rh�|,ߦ���BL�br� \|�-���a��rd���Nů��I7q��$5���0xW��qچ�%}<UЌ��-�ݥy��l#�n׬�OȺ���i�z�],��T�n������D2�7�9�9�(u�}0�9��`X`�7֊ [8��z�MgrV!�!�y9���ѯv]X�{��l���>����!�ŏ7�J_n�N2P5�!8pp��������{�w�O���morK�)ր�s��'�ӱ�RrH��#)*G�ƻ�ƛ�O-�s�H��Т�]{���x�����x�O�8�9���E�QXk�Bvi��Ȍ������D�,Y��3Y�FZ�&����/�?S =G'TiNs�'�g����|�O��ݏSR�}ظΗs���2���}5NI�4/QL�?"��Z_���
B	3O)k'�cp͹��QÃ��{/Jݠ:M����j1�"J�e��l��i���Q���t��A&���gH%%O��x��r7/���*�{���Û�f����D5��[WPY��S�i�\luϼ�b-�2�+���NM�n��z���Qj�y����o��?a���      g   +  x�ՑQK�0���_��*i���	��胯s��ܕ�&������Iۘ�B�s�����tZ�/�yU�S�Le��UӺ.i�6�hC����/�q)T��,�P4���@k�զX������І�qN��'�!����3)�V�̭��=:��-%(X�Zj.�C�.Qy�exJQAϤ gP�#g��Ķ���.��F+4��M����Qu���3��/���}�e�G���\Ҡ��Aw:����C�4��:��"������ bJ�L��Y'���s�� >��$��Ս,������      h   ?  x�՜[kdEǟ'��Ѿ_A|����7�h2Y�w��0���Te�aSa �I}~�类��3֜q�}	��cdگ4���Cʃ3쾦����{8�������	D?=l��/������-�>�q{G��tn����ϗǛ���ý��������������_��;�:�^�K�|��D�x�[~��p�{}�����N�PX�j�K-L��`���e��sq��8~T�:rr���R�#�R���>T�����6��5��T0Y�ȶlPĽxSg�M��=8R�Ź���Tfbѓ'�A�	��չ`��f�(&�A��M-�al[�=ٖJ� o1��8//I'0���FgQ��,S��ةyR� �BƔ}�2V���i`%GG�j��řZs[�A#�ɑZ��Zʾ֭Ú��`��Q�\�7���[[I2:R��b�ڜ�%�Π�;�#�LP}��o�TQfS��đm��r� �l+�т�C��-� g�������2;:;�A�:rq�V�Ǽ�
Ƶ8R��"a��]��B}������F-�L�|�)�* X)Q�����#�w4������f��P����TF���]m^��ի�v�����Ǜ��&Vk��Zf5��L�(��7��o�~�����?<���//��П��\�����|wC��?����p���{Oю�BnÙ�P�%60؆ď۱A�9�m>����
6Àg�9S=`��l�ejqC�)::�6B����P�h`-�����R��L�9CR���D͑Z���%��3��4�X���#T۬�WY"��6/����7?j٠ ����Bʬn��L��(�5�6��Ř��Ğl�Ճdg�p�<T�޲�rz�<���p����8%;�-T�펡l�9�`�l�ޏ������֐��ι7������jb�|����I���Fr�LP�	ygjqS��O`�:8R�U��3�0���
&=9�+ؠ���,�P!�
��ǭ��(��b%�	�����c�>����Q9CjB*��ş:���8�$g�a>V h	���-���ںZ���y�0���q��'���+�4z�57�I=7����*ņ�^�����mq��9�P=l�Ԫۏ֛xR��yDp���Y�:�&�X�e�8�jeh`q� z�-T-@�<a.al��ɳ���,&̓E�tq� �Բ@�Pɛ'̢}��	rp�n٠J��^��[�!7��ɑm٠gyV.ǒ3uΠ�^�Z(lнE���HI�Yń(�sNg5��,*3����A�0J���&��m`R	��C���*�D�<��(�ƶLP?~yuu�7w��      n      x�̽Y�G�.���+��ڔe����H�gD����fz�%@��F,�����#�l
HK�aΙi�T��+"|����+�g��"?O��[�Wd%��4�~f6,V�����������A�q�d���������lq<x����N�����zܞ��{n��^�)����bmV&I�8��,� ��U��*�M�~iQ�qb��>���ܾ�AE���������m���	����`��8���yW��vO�9��G�=o�;�ڵ=m(Jݩ8�^�k�����;��f;�}>п�6m�Y�>�>�yxu�J��R��ť��m�п;��W{{�V�7u}�]��k�{|�]�ݻ����~�G?o.����S�����i��-�
[�E��ce�o��l���D��4��۷����=��\�]{z���?�[�d�ip
N� ]����N��~k������/t*��X�a��T�v}�6�YN�fK?ȫ#�����S��UA?X�ٿ��_�}��+������m}��H�8��Σh<��&���'|3�cQ�=��ɱ�ǲ�:6�2ǲ��j�c�T�In?�Qf">���㮨p),����z�zņΊ��]��������n���wO��"�t��\�/hG���z�mZ��Q�������=�ፒ4
��5��;����|;�9���O�h�ڞ�-�nK����������{�u�-Ϫ��`_퉯I�R�l}��K�n�����H���آ����Σ�:�c�DIB?XE��E�Xظ��cP����1���"���-*<�UK��lOo����3?�ޫ����Q۪��H適�V�I��8ˣ��L�7˜�(0Ō�&����>����nO��v�����_p�t�����a�'�I�0X8/w��<�f�,	�6IW�ݖNƁʓ�e�@^E�IG�$�z���(^�����(���J�&��@���g(��� P��M�*�[�Lٷ��!:�D=!k<x�қT��+�-�bJ�j)W�{�<2���۴܍˒��n�V�GY�o|��L�v���s�q���ʳTtXX(z��*��]����$��9��C)��X�~���M��Uq_�F��Qs�)��;n|<�{��lu>m�QaP�dm%r�ro�%��IXL�dt�(O�ܿ�2�m6#,A��5��/�Dٿ�R}p�⡶5�7�j�X�	�~E��}�(H�L�{��G��$^��MF?@\Z��[9P�Q2�ʅ~.�
V?S_�y%E���x�)���X{ǖ�$�n�:��7����ߞ:-�kj%�Z5^�m�4|ywZ�'5П�Ԅ?��h�8��BTP�W�	��!LL�/��N���j�)���9��u�tw�ԕ�<=QU��t�Noo�,v���Pt�a�~i��u?z_��v5���x%�=��t�vO�����I#����q�׫1Q9����<�9�����~�M*�-2�A{�J{B_�m�i.J��,\�/v�:�3"�a�E�IV��{��-������n�W��`�4��^[|��,=_�m��L��O���BGuM�^9Tn�2	nD~x��2���4'�x�8����BD�=P/�F�+ʝ�}�J��m����Kzս7TaأL�N��v�Ӏ�!�|�����$JR����E�� �9|*p'�֓��/��Q�7ۃ��t�>�	~:��g��sG���s3�h��;�O�	e륧fK��iP���an�&�#��~��C�風�ۓ�6T���{��u�=`V��t<�ā�.�=�j1>q�~����d��*�;}'��L����OMɶ�=_:[�F�@/Ug;����m���|����x��o�d��+�62���u�����������_���*��*��(���@ܲ���L�pF�	_Q��Zn(mw;ȗT�R-��y�?Q8)%׼6(�}Klb�}���^����L��4�Q�����jۣN+:T%|���ųݩ(w�"�AÌ�����j���=P+�ޜx���ɇ?�m{�?���rw�Q� ��Kt���?x�l�_�w��û �� ���ss|�Ͷ;�G�<�d�/�����+K�#��czG�m�����cO�K��H�l������:�]G��,����*]�X|Z��S�
o��4}�g� �Z��-޶����l%<�~eE��z7=cA�x��������F���QT��:��l-����h�$�E�vt�v��/���Dt���v����V�����%���U�0H�hِ�I�����vƵ���e�O���o@���N­P��E��cn���2��iĲ4�����:��WLq�&i ����F���g�A[J���v�ikju��w��8��1^�h�al	�M�zF��i,�� %�m=��w���q���>���뮄_�I�(�'����Pq1#L�	�P��tVt.�mgA1(���1�/�t�>?a�Vko{8���-�MGA}��"�}�0�[�E�=��[�7~4#nc���]ը��k��訝�B7Tg�'�3ѽo��~���Q+d��n��<�>xK�y���?��������|�K�R����:�;Em۵�Uy�2�(�1��g�]⤎&�>~K%�<LL9#dI,ň1�WM�KG��O��?�����A@�5�'[=b�y�"���%F#��F��*:�f(�(fQ�%wZ~�Q��X,�y⇑nz�T�VT�s��A[�i�r�X�7��Q*�q�����8��4���*OL���}R��@�]��U���"K�1+��. Q+��i�(�ۍÕ�h~ז:S��$���$M�@���/ڑ��#�*W/%����*^�=x_eMܹ�ޚ�x<��FZ�v��'�{H���b�64�EI��$�iH���G����z��a���:4E����ʺ��6R���CnF��swҐ؃v��^7�<<�����2�I�2�������E���3��I(S�WT�d ��I�1���sG�CO_o��NZ4Yw�c�L�+-=�5^��2uZW(?:x�������i`��?��3�z���3N�� {K�=e
�ˠ9ŭ����;A����:���ꤩ:��*�cI���VRU(��#W�����KM���pɝi��B�3�=��Tn�XP��)�j��#�c�7�����/�7Xs��[D���R�k�Z�����k��^js�V��/�\� C�������+�g����i�͌	��v/E]yFyZ�n_q��&�f�'s O�a%z!��^Om�Z��SKm�/��x��NC�f����p{��l�� �̚f�[A��c,�8Z�&q�pFI��_$ZI^ķ��	�C>�xA�cѿn�r��@��&���9�����?:ɦES&3BB?R ��A<nk��x���ǌ��֌����ܝ��Afy>M#��A�p�l�-sx��,o��� 	S���_ǖ��N��U`z�"�����NZ?�cy�LnK�s��3������N0�����)wdb�Ļ��A'>��Q�������]:N#G��O��J}p��Wm���]ޅ�=����;J`�Z�I[�!:��~T��p��T<qj�����Li��p)K�J!����(qX���C��G��*Ux�6��V�:�e�ꏪ�����h�)�&� �����˘הkn?bahd�����2�r�.޺�_{Īc���+��8Ha`�l� -���2�#D҈r^����ۊ1��0P�j)�i]C���H�%�i|0κ�.�2Y�ψO�ˈט�?��Is��饻��^Ӌ�A^���0�z��"��*o�(�y,~�1�41cח���d�u��N�팓�xo۰���`�JUT�^�O��
r�&=B�������C&u�$P�J�����Qt���GgL�4s����<g����l���Q�(�Cs��+�O��r	x�)B&M�>]�)[,@M��))����bTѦ�>p��,�hI���ި�yN��g�ҕ�R�|i"��x�3��;��'�c�S���N��yX���=P���O߮����ui���}�澶�G��cGm�y�����{��m�w5�k'q�R�,�    /w~�2f4{y��ɤ�_Q�r��ד����3�U�&�1��1�%�`:h��dώ�$�YZ��������a����.�yuH�YY�8a�7I���P#H=X)ҿ}���މ����x<\��/����y�Mϑ�3L���jg�85�w�
�'*�=����{��
'�B��Bo�T��0d[oz��}�Y�t�<�Y��=_F�{�Ǜ�e0����k�N~�>K~���]u܂߾���I�뜱��j�5��8��������_�Ў��SFu���~�o����<���(%&�1��L�bp����U4���蛱�;���C���G��Ð�}��vi/��t��� ��-k���A"nRЊ-�>����aJ�û=x�'q�h��J��O���Y;*pj�s�~j����ڱm�t����*���s�9�����]N���Z�{��?o&9\�o[j��Mb�k�����Dm�7�����8�
k�W	b�7��転����{P����*p(�#�/����/9Y��w���\{�����&�?3��w��ԇ��|Y`�����_}�J�B����x��
�m�����4��/�/��p��YyT$���њa� �t�: 9'�,��0�ע1��ŋ,���zCQ9s����(W�1qUP}D����7�>�O�?|��NI	Μ1f�D��χ֎@9�Z�<=���fy�iKW�UỶ/r2�e�0���~\��pP<��|p)���-�P�O�$<�h�G޷bwfz	Oh����� �	5I�Z��~�HnQ�<�
��Wd��5k�'e�|�������a,�#|;z,�L��*�R?��"�
����&��T8$A�z���O�h���IH�x&{��	���.�C��
L`Z��u=���I�w�:)f�=d�Isī7瓾|\}�:Q�8X0d���I��O��T1�z�ď��+��n�͋�s��Q&9��H�-���P_����q?Y���O(��w:�*�*�nǄa�g$D���7=B�u֠��#g>xBj��)EL��=�?l�J�sBUs܊ҙ\]첨��j�����s�pt�u������0����;��m�����!���nP7��!(y�<
C��:���{�&��_̯E��k��U���gLL�86��T~H�"f�����8�ʶ�w���dy�]	��!�!��ܠ��~^�h���aQW����A:#dI�
���=�)^{��C�g�N�a?�yf���C��Þȁ���~ғ9�_����Gn���6��R�Ig� �~�j�hp�(N-.��C�=�Ld���Z�2�Ƅ�OX�4	�H�G_qP��p.�P��<'�5d�#_?���g[����ԲyY�p���L�W����8H�<)���|�$K�5�MA���"Q�� �9x�M�l�Ų�8ʣF�$�L�vJ �Y潓�fA�\��gm� ��<��H L�d3&�h>�\� ��h�5#��8}�����3CL����@��I4� ��;ͯu`��~������Ｉ��Ǌ����ܸ�J�G�R��V�Ô*|�1�5�U��j(��etB��i����	��#gL�P�P����;��=�����G��;X$���;(�)�P%����q�ö؃��f8&�,�(�翭��]�z��:�Qqx�w�B��ć�� �zN�㓆Y������2����������WB�B� ��gf�_����&Z�05e�-���g�a
�P3=���P��ur�B\�zhaj�b��3�*�h�|y9���I�̤���?:�y]�3^�(3�#9�4/����7V�-k-@�e�&s��V7ޓ�EI����G?���An��C'�Hl��g��.x �R��
`0M�2/ ���o��(��������%�T�3��!�K�0���r$������\�֦����p�@cdU��a�����@xl����� px5;� ��?h���'��\�~��xT�B8ɶ���9?x��b:��Y��pV���8��pً�\1Q%e3��H�,J��E��Im@��R9����A�S�`����sv����ܪq�����6Q�ѣ��iwӼ��	�wݺ0vF^M�\��&Y���潪���nMw�k+8��$(�I|�l���omag���1Y�p���j�6�n��9ԁ�����<��M+�����q�ވ�X�3�z�4�Q�`�v��� ������T&�IVNߌ����_�7	u�ٝfDk(�3
�<��L�;_��<7D<�!\(�UpBT޸é#�Mߠ<5a��u[,J�5��/��GHx����q;�r�%�k��ZT�l����YYP�8�51����0D񮹰�<�(�Ə�<Y��-vE#�T�����O���Ee��I�Ⱦ]�o(D.��T�D&��tDa�4Ln��&�B)R��ġ�,K���'�"��?�^!E"/���L�l�"v�*�0t�ΐ�C�P��f����y�`��va��[.�IUܬzOQ�N�h��E�a���Q�{b�ʘ�Kˠ���������T���.[�WL)�-��<A]m{d=��5hwg�uQ�.c��<�v�߶��%ҁ�dC�	�'��b�<h��W�CѾn������=���GF�H�4RU�Ȏz�A<YU'w����� �;�W��r4z�nX(׶0���=�Q)�����$ߤaD3~F��Tn��#�*�ZJת+�Q�0��1��]�g&4��{�����hFV�(ц
����G�j�U�XQCPa�M
/j��r���;}V�GH��E6����Ͻ��6��xF���@f�A�z�ڶr<� o����� �e��zk�Fz��Iآ��齆��n��S��8NE������q5z<�b�?b�X�s��^�O�Q�����QaM�Z�\��0C�Ix�(N�o)C��ٙ�$Y��:c�^x#�k��Itc��r�.>��1;��	�c@��B�$���&�����d�?#�i z�ߋ2�^N.w�BA�M��R:��f�VH=�ꥌ����<S�e�X8�3(��X�g�{J�T! )�UK9�.2�s6~H�ۺ����:d��aL�wfu@�ɱ��0����i����Byw�)w,��#�E��Z7 
 ���,#F�j�F�fc�苞Pu�vnVyt@�{v�d����,�I�����P&ad�]-WxV�03�M�
\�W?ӯ�i>a�?)rN�ʛ�_��쥇�B,�is�:�w�u7IT�?�A��������A��X��1�1��f� ��j]ĺ���K�П_<H�+�_ҰkҤHnlT��AZ}�EM������G8�t�3��� j���a{�`��,�1E�~H0��x�v��٤~S8]�7<*�8=�c���<:̆���c����
R�0���� ��[�d"ĩ'i�苲y��2�K[���X�#�#s�qh����cv�t�^��}���q��u�V� &�FEN�X��⠒��	���5�`]�3+�*�B��w� K�1�����n�����j?���6���4ءQ.���=��{eUZS���u$+	#�3y�'a˂<�Z	���$Ul��%/&|���w�?�f�K��߆-�釒+�F.��k
*
.�{�ߑ,�W���h����}�w<Tl����o0��2�����`S�J%y����G�O��}�ȃʳW��(O�_�Q�R�l������|?M�ۯfH�w��rY��U���qtz�5���4,y������ثW��~Ws��Fݎ�m-��x��x�O�=)�����m�ڧqT�3�y|��% ���
/6a��`���n�7h�}>�Ҩ��v���D7��YA�p�_� e�$��[*Y`��t>��[Raآ�q���j�	\Q����ο36����$���5��qF�4N�FǐC��P������ll�%�O2 �>��̍��J��@gG�&&�<tY��l�**�a_G�X���� �&V��'`1eU��5~|�q��yIS��#j�؟qD�8T�����S�a��@>w��Ί�{�!5�.X�u��d�`�I��+��}���==��I�\�į�]ϓvj�T����}     �	["?�.�;>QV�,�I:q�΅�.���qjYA&9RPA��:�����C�^�ej&QL���^�Gg�8���g�!��ҫ��=pg��~%�]�*v�w�?����c��FMhGYE�8r$��$�a.]�-�$��9A�b��fIG̈́fs&����w�H#�{�
T����]*�)���(��^'�_5|aM�a���#N2�D�.�5O� �?	U�w*���:��M���	W��e\��#@+�y_�����s��)��LE~��XvȊrλG�"+��'��a�2K�q��J�"����lTL]y�t� '����x�O���g����&}�>���<�u1#�y�;$-���n��}���,e�ߟ�E�I�JL����0SC巇��z���9��$�9�Bs��G�iݾq��y�'+�P�����(�y���X�H��^�����l�&q��%��5n%}���/���I�B8����^�HV���~A�MMH����M�~��}��0�1���
��M��m�=<Uo��:���#E�{�K��t�X\:�T�'Q%����fi1#��t5S��2�P�����ՏieX��*�����6�uTP O>��jl�<�.�>���{���F>�Fq�o�t"�p�gF���y��I8��̢c�'�;m�1����0]��n��Ȫ99_�q�#�d&������o�E�O?��l^y��S�TK�����ÿ��M�(���v[�1Lu�>`Q���ۣ ��<��r'�1�Uzu��V���_��x���}w�j}���E� D�8���aF��%s=v��L�j�:�zD2�w��G�St	e-Y��Rx����!xŷb�c���T�yh��6����TX��'�eP��wz�I��
H����9�;ӢA�,��K���Pپ�er����VW����?�H^�&�<-���\VE~{}я����=�L�iEՐ�b\,'xc�H����������tP��x����(ͨ!��v]H�2��	iU�3@�Q+=+\��>��w�4���Љ/���x�{��n'D�|��P�+cԄi�H��jnO�QnB��V�����{��:�5�8]��A�3�3H0�mO6��2���������3�(ObQc�W_�Ű 쬰TU����Çɯ����4fq��z�� �!v�&�Ԗ�7C�aP�<�Q[[����N^<L2�,�Ɖ��ž����2?<rM4"�����"�In�9�1%{����W�� g������$���T2�ʤ���	��V�dl x�2�?��u`���P/cp�G:T#����x~� L��*��+t���v�r����{��A��.G�M"�#����ʹ��±]c�Rq,��,i�ר�R7EL��3����:�_�<n��_�Z����������8Tg*X�&�B�g��fd�k�mo-���p�.����*{�x�n"��5sL�a��]��h�uS���s�O��V�ő
����, �ս��`p>P��=�3�Xa#�ã��xg�I|3��_9C�&���� Z$�Ue3rL�a`G+��ޑ�\��"������1@2��7t�eI^��ze����uU��,
n>�y��*���q[Q[n>pMk�ߥ/wp6�)�tp@�DWdZ�#X<��3�s5��GӖuv����Q�%R#��GV7u����J�F��k�YZ�	LI=q�2�`<�����zD���E��/��&ˌ��������]ꖇ�)��5a,�i��'�AF���9�t<��0��ʺ��$i�H�	MV͘�PW�g�?�,�(Q,A��0���L-U՜&��d�&� aѧn���Ur� !	�T�rz�TUJ�[L�W>��Ȱ%$�\���p3����:�W1T�ܜ��W
�Z�3�����?�ٿ��o@�m��Y�7��$�^���QP�.�*Bx�ꠡO�G4�}��+s50�C��5�<�����s9ѣ}�a&��NgԤ�#`gu���j���SP�%�Ҟ�w_��(����"g��Z�ƭR��ܡ#��v���qfIh�4^�t.v{���n�Z&�����x��Cc���Au���A@NńX��)���`@�f'I�~)��V|?⢦��٢���=nlx{A�ā���Y}P��K9��k2������͘e4�<x@;��g�*�,+��\'�A� q�xMb?I�;me� lf������΋���Ô�ߜ��ډ_+|���4�����Mh��%W'A���A�)^`\6Q���0|@'"���Y����7���a�C(�������؄��>(0�y��F��K�(������$SΕcJ�狀��[PP\DWÂ�H��#2X�>q�����v:R���N�0��'ˌx)}�~J�+MM����QQ-p������)`sJ���|ɨU��溎��zBc�E
��ԫq
-�r~u>��N(�\Ĥ��*��mi�������\���c�v�!��ye������r�ñ�ְ���GI�0*�)�j�v|O"z��WQ�}�h;3Kv������8b\Tg����YI`�T���+)���|ϭ����f�#����! I79�,�"dzW�BM��w�+C�'ߊH�R�����*UԜV1H�{D��ߜQ�@/`P�A��;����*��b�����Q|�*O��z�"K�q��u.�Op���U���\D����A8� �� �~5�br���\���Fm�����D�W8;rzw�3�m�`r���Nj���*�F	M����D���˽r�>�T@@�Yf���T��[�����?�U����9�L_����
��XKC���2�/:�tF�1�?�>�7�2V���F��+�0um�)�'�$͞�9b�,"_o��i�Bf��d;�g~��������*����q:K�(�̵����&Eef��Oe*��>3O�<�Pl��s)���U|��)bn�����0��8ϣ�?:TuR�X�f~�]�@���� 2��~�0��9�N0f*�>+Φ۪Br���2|L�G3����uSP�_�S�:{�Wu�W/E�����Kf�ɵ�|u���č{%G�����x$d����zᡚ���az���*F6(_t��.FMP�Ō%Q��#.w��zR;�AduϵG��E7Sզ�mO�q�8�_�^��,eQ,������,|q0�V�@)F0u�M�l�u0'1	�L�V8��Ė3V		)5����e~��
m_E��?l�iw�'L�L)w��@co�A���7��D9ʮɭD�b�:5q<�g��ڴ�f̉|��Wn�:��N�g�z̃Lw���r��V�)��\�@��3�V�.��Y�M�L����ؑ���nf�H�=��c���ʤ����s>�2�!�����e$�9wQ����+hu����.v�%�\����4�&ȗ=͋�����fF�wS˔��LR�$E�e��e��)����~�ɌMBYf��Q�t�'�<�m�+i�D{��g0񉛊7�(�wS�e��)���^�U��3V�Y�y"K�7½;n�GG|�)�ֳ�Q�T:��p�,
#N�˃����I�\]��f��) j��ދǭ�t.2��D+K�d�6�M�H�b?-f\�8rV���ce�4b9��	����Z�M��C�{�8�h��d��?��t�$�6*�u��ѕ��KhN�
�` �lY�Fhb eȜ��/�$Zy��z���D3������w�7ȍ� $�K�d���!=�L5�{����;��°5?wJ���{=~iR���e��a�	W_-K/�{ѯ�'Wm�Xd�0uW�?�U1%��*O�l�÷�ӟ�E<��Jcݕ�h�ɮ��j�2]Ws�/G<�r�������L�!S@�X<w�v��\vFZ�cp�1��@t-�:3��������N�|5���d���e�����v��^w��1��8}���K!S^��IȐ��J�(�40�Fn]�aQ�A�1+��=	S��AP�J�	$O��<�B�I��勧�>�����?# ��n�6%�"�x.�b�( ����"�S���^vL    ��i�$�}����7K�ً�	����9|:Wwb�-���ܤ~~�3`�&x)���y�3EYc^���M�̐g΃(ȕl@����cG]�	�Z��r�=׃��~�I8��AE�bU�[���aK����H�A.:�P�a��g̽wų�g��?E ��9�%�����>D������*,�����f�{�:�
���;����U%��n�>a%į+�N<�?���Z%"X��`ye0��ϲ��N�;gYYp�q1�=u�wb���m���c�G��fLĤ�7���?���(����.J���2�����D�Ψ�Aǥ�s�^C�������\s���/%���ł���F�13�{XClX$���Z�0���6h�D������ ���W��ə)m��z�V���sj���8^�зl���u%]��N#Fb�}<��QJ֊��N�Ծ=��TXt�e��ql�6��ŌƉHQ&*>l{��t]Ghp�b�ްc���'��\�*���a�*,��*��B*c9� ��
������8 ���zn�,����cin�իF�����l�2V��,p���fYؔm���Ƃ�xBe����j�-T��;@�yq�tJ^,�q��3��Ĥ"����Pc���x���< l��9w%�Ay���&ki�
`R�a�6^�1,+#KmXz��أ��"4�C�:�/$���Q.ī�%�z{��DlI�o�WYG+���B��� 4l��=�I�dx��ˡv ܭ�	����͝��I{�癩��z�VR~F�e�zX�P/��YxL0���۹��z��v`�VTl��2��=9���#w����Bs��4���*��~v�0�б�O��^�@�%qx��}���K�T � �%�H�b����,�V����^��/��U��^B�'u�����5a ��`�J�Wm�mq��_�|��Q���U�8��~�D`��v�����eWQ�Z-8��w:#p��.C���$dn�s8s����4�������9C���g(�XA��d��+����%j#�MPB74Q�V!�/K-3&z��j\58��1k�3��������`Lp��V��ÍC^-���m����@�<�����R�T�'�?㺅��$'�>�h�$pg����F� 3P2p��%����l� �4��I��ے��S��5�?ˆaB ��mjr�^���k���(��܄���� ��r�Bt��B�M�#8��x�0��>GK嵌.��}z�`�/d��ɂ��v����)�J�I�37��\E��g(�,�:;j��B���2�ự1~W�dW�}��/�6%�<u��g
ä|1�����A�����V����ٵz�I���Ӯ�����(�'b����8ET��ǩ�_rC�2NaV���8%�B��*̌+��v[/:|��t�^���5uq{U`R�O��z����;��֏�2�l��#s(z +"�qu)��mun�,̯~��TXĉ]$P	H��*�V��O��1buUNs8�]1��5?	M
|׽����dFh�L��hd�\N�6������m�n&�ɲ ����ч&ύ���y�+��&�DŃr�%�i��������,� ~���}����>	�+��tQy�t)ЁZ]?�<|a�A�˛&Vl	 �48U�&����郟���� &���)@�������q�gc�8��<��?3@�`1���5k�@\[F�N?�7|����;��:]������a95�&~�ޟz_U�D�sR�����VH��~'V� 0����3k��8:c��I�!I}�@�G�q�\���2���R�~��C����L��q��2L��������ecfUC&���� 
��T:��Ņn�o"H���:�����ة�μ�C�)LH_�^��͌�~'
E�F����xyb�X�0�R%;�,- ��%����q�<�#���K�&Z$|uQͨ� 	�Hq�_X�SǞ�=
�p�V���]�`�V t�����\Y{C�Y��q������ٲ){�ۼLn��0�L��_��'�rk�����5�D��0���(���k�פuS�Qfd�h��o��������>��Î�":��J_x�3s��J���a�<�@!t�G��+k�� 3ŀ�����N�z�ȠF]�kqp+^�;,&6����y�n���vC������/E��8_x�Օ�)TxK����a802gU�=L��� 	���`.95���z���H�0rh�~�"����&3����a��i�~�0I3���)pa�
���J��_"W�o/V�S@k �:�Z j�\�M,fD5�o�PN��!Rn�������A�u�q/�D�����꜁{�"�Jx1�xR�8{�������9z��J�Q���g����Y29�	��-{U]X��s�S���ޒ�+};(�Ŋ*G	�W_���<�0cݻ�<�M��P�oFq�$����g��]C����u�,ρ���(Da�a�j?j�(~1�TAP����&��!*���o��aL�J���G�I��;O4�1�r��	u��_2>AUv���,M��I"�rW��E��Q��n�P�M�M���
����5����p�1O=�3PAf��w|a���7����k�H�B+t�����K����ʨo�u��<&6Y8PMU%�*��Y�ʳL����'�բ,����,b��මnF��y�����M��>TQQ�	[��D1���T�=ZQ$eޟwƨ�u�����">p��tbVQ�t�Y�P�JE��SoS��P�U]����|�U�
�ݠ�wV\2X��`�n�[��+�\@����>�jkXf�B��?���?��7P�z�d��bè9�.�U�w�I���BS� �t*/�F��"C�܁�*���G�f��y�
�ysa!��e� ���Zd��I�����t�q�d�z:��g��,#����:@aܕ��d=Jx����BН��G+^s�9#ɪ"�5:����� �iA��rd=�'Q��};:-��Ģ_k`�K*N�yx�Ǐj����Z��aɘ��n���Q�JЎ�����(6X M��3{$�
�AN�R�Α���n�<��L�Y�g�/�#�Џ���_٥L����ZO�vS'�����*�oY�y���}L�����U��^G�8U9� Id�dC��:�#u���<����2+=MEDˢ�x�MC�b�K���V˄�����&ږ	V?!��֔��n
��e�.�{T���m���+�D���RDX�a3y��m�Q�U2�ąƈ��	W�&��B7��I4�<�ﶗ�qU�>A�"�i��V_�(ǻX���)v�}r��z�zD�e=3���!ܰ}9J/��^��i��ۉ(V������l(��X囵{V[@U��4dS0=�+8Q4�'j7�%@"�F}�Pi������@� L�NK�co�,~p�A�����,w�����9&��Xa�����_�8�1U�02������H�b������ϒu�����ײSe��S�y�J� �s�� � �G&N��W���I	���P"�&FD*���G+Vg/�]�A|�#��d��]���M�v�+�+w��2o��_�3Og�^L���ab��>�Am��4�c_*`�.����HoP_d��==|"����k7vAb0��wZ��Q� *F�o��,[�r�N~Ǵ��z�����Gu��+7�A��(R%�d��'j��9	#@�ѽ���g`|8C�&S���G����f~+����yP�<#q-�}vƁ�#w����e��^��ԉ���q�r.��M�J��V�-x5?	F����K�qeZ���������	��	��.s�0B�ˉb,���6U�AI�"���^e�y5#b���ׄ�-����ԂK�8(1�.a����?��
3t�$�����q��6��l
�!W�p��S6�����E��g���Q�%��u�čd8�&Ir��0u�\�I�D���    -{������<�<�Rcp�S=Zv��*��{�S+�b��-U��I���_[�0��	Ʒ}u��q�.�J���*)��n����G�g���J6	jnb쟯��+��j�?(+��x�h�j�g3��%����9���4�wj��	�
|�Y wY�B,���B�_ire��4��EbI���(U�y��U�X��I>���b�u��pSB;�[:V!�P͝-�qa	'��X'�2gM��>�ԋF���2���8��;H��������gK4��ȇ]c��dmT�R#���c��Q�8��h/2�!�r�<ɯ�������MgL��8������n��t�SOa���% �i𾹖7fu���*��?S���K�~uS����7M"�� ��O;��j6�q����~�������Ô�yp5���0�͋.\ׅ��EV�8=)I�ʽ�z��_O;�f�g���gf<�����1�zc�?�[n  ��/��ͤE<�x�qh�9��82$�r��4Ȭ��6һ8a�>�LEY���[.2AT�Xç������n��ٳ�Ѱ`$�dJAU�F�W��x�k~�����P�Y,{���EM�+C��:#T�
�'�:�w �N��P'�h���?n[�׹�4�$dY�gٲ�Ղ!�iv{���S�1�y�ʺ� ͭ8�11�����P��4 ^,�Ɣ�J��S=F�/��"`3Md��R"��0K�R9�Fe8C},͓(2j"�����F���0��A@��"����ug�{'P�
��4�qb�&2��`�)��73�M����y����k��-�XZ�w]%����u�c�Щ�R�˙�W����8���g��׼�Du̈g���v�: ���cK_u��WnX�Q�W
���xR-�DY����-���x��v���̵Ħ+�ka�h���&�A�ͨF��W���z������P�d􁲳�U4��W���̪�D˘0�֏�������L����C�Wy� �x6�f"q��Q��Я����u�NC{& �ᑃ��)�xМ�g{f�G�L�2�Y��`�gA�Μ��V���D(��P�9�:�����"��>���$|����G�?:�乭g�� ��D�L��*x��0D��bbuɌ��u2��E�\�(�*�Ob�2��aՏN5E��(2�01"yib�<2嗅���� �����7b�~�ţ$�;��Z��>8���<K�&��������g۫/��  V-Tse-�-��$�W��-������?�s�WWE-
k_�Z���E���M���I3��^��O�6U�����9[��B'�������b�,˯UD�2,�2�"a���a�u�>̀�zfuy�v��RB|��L1���6\O<wj�=�vb状��
B�A$������żr],�"��.�G~��^�vϴ��X5	�}����ԱD�V�W2�Dt&L9V0�I52�e+����=��E:7'����+�:����̓�I(��3F|,p��L?`���;��GK��;�P$�tt	�[�������Zܟ�z +lk�O�������,լ���,��V�A�����m�\)�v`�5/��]��G����P�_���;X��W�ڳ~��O[
2AՅ�v��S���s6_�uX��l��o<�a(�LA��^9�"�ʔ�����!�;����~�<��8,�qbclҼ$h�P�꿰��2qG/�$����
I�Ǳ�#���ѩ�i��<1��@S��}�4�%��wv�^�a1UR-���nU�EX�(	Tn�����Ӈ�
��)�s�OvQ��`�=���?��U�3B�fN��7��V������-�[X����Xk{����E� pI_k�}e�Le^*�ְ3�&U�ΟZ���4�q�W��f?
��p*_�4UI��ų~x�nA	�8Md�!*�z��%��n��$��f�y�o��A4� ��,4��~�Y�'�sD�:��ƠI��>���nn�[��+Ffo�߶�^�A��)�Sz�0���\8�t�B��d���~#��aj��u� �~X����� V=��{P��ϕ�$�{���m�T��c�+��^�`�l�����	�e҈2lz��54i]�i'�.:�p;!ME�O��1M~凩�I�'e����H{�����r���b"�Sh���|d�l#�ݯ�8p��RT\MA�W�}۲��@if�	G��(�3 ��kuN�(H}	6�G�����9#����b��)��jU�K4�d=����XkZ�OWD0�>�䎣 X�(�W��+�?�����E��i��ǽ�>�^;9�q�ѝ&�0��xƋ�D��d��Q�%����-��lu�U0{$�H�4�SKY��	�L�4D�x�$�cs��a�I=㎧��;jvO�Q��v������cDw�o\4i6����UV�I���X<O�L����BIP��|���^w�y%5�=𺞁�� Wwr|B10�~u ]!H|�i#�A���� ����힍B(<��d�?#2�����jAO�����?�w�j��׀;�$t��#�^�Y�Ǳ��L5�L���"�׫=\X�a'+<-�p��q��	�?B��Lަ"1���4��J��#̚,�=�)�R��M��{bfKO�oT�oTQ�g��p���I=���`�UO�2��l6����㠂E���wy*�ݽ�~HM�)a:]�~�)�7B3EGe��:�����b��K:L��~*�G��I�9�1b�z��mX&����j�T�����K�U��z�%x9N�J�Y���s��
C	��>55y��ڧ�~=�.�:O2@�)�D��t�˪�l�*r��b�}�6*�$%��:V��q� ��I Cߘ���r	�b4w{ ��	b��4Z͗�&��2���3��8��$D����NC�q��> �=K�0����X�T� H�W��S#V#���M,�(W<x�u?��'���/�M�x��T��*�;�`&A��%Vw�=�sc�P��*Q����+�CG��zQI��v�E|��0=f��h&���wZ�DaT�3��a�*��-E�	��}�U%�n �"{M�w{@ȝ{Ռ�P�x�������.�Q$fT/i
,�V�ַ�*��5�A<z:�����`[1"w�&l0�TFX��.�8���	��J��W���ǩ#x6YW=u���Ia�l��
����8Q�{��؎��w,u�s&���^c���d���4���^�.�`�І�/�@��b� ��>�p��s�ɲVi�Z�:H�zl��JW���Wup��1�C��Y�&\�R��	c�F<�
R���?H7V
fL�I���U�24f��n��~z��u��6VMR�^�d�/���\~d$ҩpЧ��ט�cj�5%&���[��$��xx�϶��ݏh1�Z�>����b�س�Eo���y��`%�O���h>�wM����Un�"3vIt��� �B�����O*ɦ#n�O�%$� �"&�Bw.���Z`b٪�u�t
�aZ�f�B���*�Q�e���EmO��R1^H�;�'=�Ǒ��gv�J�8�ׁk��Q��8������8v}���;[x2l���a�B����j�uv�t��R�|YW��s����x���^�OV^���<�rӎN�VJ�zSdk/2�쵲i��-^��ݒ��ײ�(O��8����NlZj�O`�l���,@?����68�#� ؎x��8(�+�dX�`��A2@t˽Ұ� }XJ�~Ȏ��?3^o��"9$m��W;�=~7���4��;�CDy�����̄�,wC�π��JA����.0�j$Qv�Y���k�,��@�;��/[��q`���b-��0�D���76ԩ�Y��$f����$�AH���a\�G�Lm�a��1\}�@[U�C�8:���������m�TQE��xeiz��
'��x�I�%�Dڞ+��z�6���փG�j��`�˔9���/@'u�0
��^[:k���z9��DZ�0^��֌�h ��6�����[�>�i�x�P���{
`?>��.2i��Cט ���E��f6Y}���މ��`�W��gRB�W�i�X���`    e&1w�#cߏ��F��c���R:���.�jY�BJ!�c�7�N<6eႇi���Q�GϨ���o�9%T��u�q�h����]k%��'PA�=��J�,u.�֚b��yˊ"\�94r�Nc��^�x�����s����YK��>*���d���칮,<T�k���㱥�������D�u�p=�Iڠ��O@n�$܊�e��6�P�4��-�WoX��ye
���:^��N���JA���/'��L��t=It˔rz���8��b�E��8�|9i���q��~��V�+f�x'T�yv����yZ�����w:��273
z�D�,
V���=n`�ccW�й��<�^]i
)�Vc�,6yv��^g�����&J�7����:�
2�{2��r?��{�[I\�3�V�"���T��yRipʟ`=>#i��\�fӸ�y��k:LC߿����ό�9��kB���5��C�2rɈ��v-'�o���<̩���;]�ę_VvF� OƑKV�wb�&�G��U1��D�#e��y�-MUo�A�֌LD�!x�bm��x/hI��:�nl��O&�1�`vQ�PwN$`��w�&%�G�O�?��~��8�d ]�38�Y��ߪ �UF9&���J����N!gW�?=�m�]��3�_+>�>�CJJ�`E��:��;p�s{�Ղ�Y-x�O�׹��`l�0�$�b{�fV9�ծ���漛�c�0'y���a���}���0H�E�ҕc��XAFu�q>Xt*�O�w, �����'{5n��ȯ�hES�}�/�I��}[��6�y��`�� �q03���΃c���F�{(�tҊ5mE��<������A1���H�1ua�Vl�c5P�ֱ������7>�� �s�5K�ρJ�a�	T*��[ˋPV�qJD��D��7�ˢ���uH��S���:~�نf�XqdQ	Y���R
N�FG���������ŐK�3�o�v&�
TԾ�~[ުʭ�Wz+��y�	s�g���=p��X�<AԂ7���+\F�~w T��_(cb����N���~j������FD�/yݧ)���C?��u��T�-3� i�ٿ���"�|��r���j��yhE�U���4q^�J����-@ڑ��`����"	��h�B��l+���ø�ƶI�𾜺�1�`���������䍥� ��U��0�>
��y(/��^xE�@z&���4i����bFH�$��8\}d�7�@��J��Ko��5�,�z{^y��/��TG��7Y�L�	y����� K�D-MR����pP?�f6���\�~��M�vR�H�8�W'P
���P&vNs�I�Ö8^��K�Kj!(d?n�����x�Sg<9ZF!aM�\lO��a}�;!�HBS�Jt{��q�3����(��'��0^��	5,��B�����o��e����Y��o/!|2�y �!�����p���Nf��%�t�Ob���|�:m�wBz�x���)GE�tW*՚ d/\,�'���$'��3�щ=x���,*�9ğ�b�BI2�5�����X�<cx�~^�>�� T�������^����fs2k�����6Ke�sE�H���i�NqP��`��*���C�O�r:N�Y6�C�J�{[NE �#�c�B����<5�|?Keg�Ͻ��r|� �'A����>���J7�L���)��3�����F>}���F6��w�Y��bZ�/�r-�W'd�s����SR�wp�J� �j�)Ƶ����{�����&&��3p���ե���Q�tt��,s�c�|��Ϝ�6���ew/�|�f\���Uc��U7z4���g� 2�/�Ѕ�}�hE�#4[*�v�vjbO5 ���Pé�O/U���rrMܭ ZR�6��� ��&��3{Њ?������^�;m���3��ፋ;x�P ��P�~Y���X��2���f�	����:�;d96�z�/sTy�ql�m��h��fQ~��s���U.E�j�LĒ�H�Ž�'+*�����P��T#���!�l����s�g/#J�H�M������He�dƭ�bC�H��AtՎ��Vg�'�A�K*,����K�+�6Z�ڵ�z�_F�f�n���-����Hx_ ;�~�WH�%<n��z��	���(�������=�O4{��w`h�(0:Tw�	��\\F�T/���O- �jf�%UA1�GI�w|��H��8!�0_���;�h�\����q?~`�V����j8���u�Jj���=��N��j�Ԗ�Kf�ݒ\�:5ir�񍨛��C�>:j!�|�`�8s��B���;lE?q���u8V�`$YoQ'ͣ�
��b�f��2w:fL��)��$ p�>�����@u/�|b�]fv��t<�ǝ�SpG�M��#�^�!̇Q�^�;Ǔ��q��+�$��:��$N|9����B��90�4�85�q|�l�;�Ȧ&��)���ī7����S���r���d�Pf�LG��|-e&P�t~�Q��|u`isљ�E�_�S8�@4$�&H}nmZ��\xW5��#��`A- ����]Q��<!e��
c�fk�e$:��=-��l@|R��YuB���#��q�9�'�CG[SO�J�%Q�y?�d���#�s��H��Ni�{�Ա$��	�_ͱ9�7g��A�AE��_�����p|��0K�;ES�A�3Ve��&
 J����k�a&~�da��F�Ri<�R��-E%�؋�����p㞰���d�S ���nߜ���(��ԇ������/C�:��JJj�[�;}�!�N�ib�����q(�L�I=�b0�c6,�3V��^���։����z�摡R2����AeoO��j�8P9�Xl���0*�,\4}:j��5�����CӒٚ
:y���?��;%���;�QKC�=����{}���`{�d�4�/Ӱ$��r�˅�n���3�F�wRt�`�;̬L����;g�����]�� ��ڣy7��Q�C~����5�WF]�[3c\f�<�v�>���lc��:��(NE�b�Н�a� D�c�,�[՘���9�<�|�����Sg��k���܀�58u�=T�e�){��e���B���" �
\�b��'��<��Δ���o/�h�b3�^�b�� �&H�j��Ҙn�<~��P|�{o�Uc�_�g�V]�d�e	ZH��� #�)
3mLg��6����7�t�����kAm�A��ib*�h���N���Ӵ�M���d��	rL�t�����R��uQM"� �(�a�N<�1���,���U�z0�<����Pə�oE��U1�mL�T}B��;��*�f�V���[�֓:M�
���v�n��}�,E��R�,�r���>_�(�����u>c�l�8���g�O�[V���dV��e2�4Q��.4i��f�i��q�\�Z�z�}CO(cE6+�� ٮGB���[�Q��d�=	]�����~�U2#��A(�c��z�H�����G�C�D���N'��xl���鑙����~��@y��Af����F�N2��Hҫ�gH��ќ:Y(�0�MO�����s�п"(��NE*��*�bU*��u6�%QΈ�1�X�f����w=�OGN؇@�
���R)��m<�@z�q����Lc�A��V�q�Ȱ�d���'�WV��)�wL�Ð���'ࡠ���A��9˯���%��`,K�����<�\R�3`O���̗�1/��)����q�׌�D�󦕭(�h#xN�A5Z3�`e'�vN�˙@��tE���yŗ<��Љ}�G�L~�v�m��4bo0Y��y�߫�~�VUv{�s���	�o�YU���n�>�8�0Gn��&d9�9oCh�_�6�8>��q��>�<x��2�B'�.��&��UP�$���ɝ�xdE6g�@�D����ԌdP�@����P��M��Ι���j��F0��$S�;�>��4�i���#+�2��(I��ɪ��(��ڲoø�u�Pm�Ŭ�"�řT�_m�p��1�û���j    '3r��XNe���߳Ѵ��r���l7`-N���"k��5��t�>x�8������9��qx�(΃;�qe6(��K� 	�[�e+.� �*L�j�=�E�V&����6��װ�M0'0�/�Y�����-��BĜ�/�\��;0l<�V��	E�03Xx�Wa��<Y��*o��W��71I�J/��t3U��R�ѩD�X�P�[т]c�.��J=��	yxd����1�e�B5`�ܟ0!�[��D�e��<b�@R���jJ�/djI���%>�'P='�\���O= �}=9*�QՔ�-e_��1=������6�_�8�i�Җ��b�)��:/檞��M�ҥHv����̸���I�(��t)�i>?�g��*�N��E�~�;�<Mp�UE�D�h iyE�E�?�x�pR��%f�eq{�LUC.ƍ�Ͽe�o�9���ۣ �p���]*X�A�OVj�;�S�.�����G_ˏ�;��qd�9������H�=�#�����cO��ଌ��♺���4RY�+�4O����,=6ܭ���|cI� ��x�:`�{7���u��� 0ﴗ͓&�n���oD0OW_�yY�~�db/d��#F���8�!*
g��w�P�i���ܫ�T�O��_�Kːg��ح[��:���mP| ���6	S�Q~�aʬ�ѡ��?R����+Ҝ�g^w�����{H6�r�?�-�-SyI���^��ya��02�Z\��~TY�b񅈨%���3�8@>�
��Xd��y���*GK�ڴ�
C*6�{�c���8��p��o��`��Î���x֞`��( ���z�(�'�-vG+?�sGcx�J�gq�ԏ�r	2{����H�5-V#��٣��D-�ؿ�#Vٸ�Q�Ź/:%�W_pŶE�n�˫�жܲ��Ĉ���xQ���B��#���k18�Gةt�;��q*G,�87;fC�>D��6��V��W�c�����J���z-�`��<���;8*_M�}�-��������0Q^��0A�B�T��r}=߂�S���F2�[���|H�{j��a�v=@`)haM��x��� �$���^�ly]VŌ'�~8ɼƏV?k�䜅`M�O��@F����@�Å{Tz�C>�Z�~p�M�ͣ��|A�?^��yٞ�ĲW|��<suK�\���>�܏	T��e'�
p���뉝�Ã0�ׄ�$ٜ�8�� � &�W:�v���ҝ�1;�ON���"�>	{l���Ա`�U:2�׳<%U�Y��"m�4J�{��ED3nwf�X�t���˕(c,�%�Gv[Ѷ��%�s��%T>匓���te��VoT�cdX���Y۪�r�#��R6	Qg���(����!bE	Q���I��>�:��� �{�D��9w�}�:ܽ��E�����Rn[׻A�y�<��{u9/�з����� �_�~\��o'�d
��`�*x����v*Q%����].�_!Bײ����~���<)"
V5#�qIc�J5�`#�;�%�Bzr��f��o�hE~��᝖/ET�sI�=�(۝
* KH���e�,���2�B����MD|!�4�%�@����,f�+"��Fr�	�x��U��u��eЊUX����l*��>B�-F��Va,2���+i�H
�^dGA�kkb�
H�2�d��݁D{��φ�'xG���g�0tΰ�bh�]O��<�׭G�榙�<�)cb�w ϓ����!$�sk~�=��;�;Ud����h�����J�E�+�����^��E�34K(��f�d�������<[��fr����*�)���O� u(I��k�R�Q4#oG�:L���O�"�qV�&�Lb���}�r�F��oQO� ��KI�l�kٺ&ۊ��#�Z����O��w�����(�{�v[���<�7���+��Vu�.�m�>�e.��acA�U&�a��6�0��.�>o_Ne˥����fQ{vR���Ro�fE��x��:e�'}$ ��pN�p��݈N��<c�I��3��!S�kE%ܙ Iy	rn@��_Yx��.���]�._�Ll������Y����te�fw�s /��>����6 ��H���b�s�Z�Ъ>/�GՖ�t0y��������Kt�f��ΤJH�C�{�>V�*��lĔ?�<�?-&E�`p8�/.�J\��ֽ}U8j�-���'���5���G�I)����+��i��*'�uVV�j��+�,Wɯ,�<
�^N`����M���U�GE8�D�1b�`�^���,����z�rW,\�)�8���	X���*Y���������U5HJ��n��&F���=_��Z����l��8��r�������!��-�H���4KWZ�ԅ.����'^Y,�&��^m2x�>]�WD5"��\��-�F����
�Y�}%�����W�ՒX�5�ci�/$ ���Ͷ�	��}D�3$0�'��:b��dxP��H��j<r<N9.^��jKcV
~�������ΘL��.���WH)C��� 
T�Iǀw��g�dSBZ曟/���>�x���t_x�b������ڼ�Ϊ�2%g��e�|�>'�dj���QuǍ=�^,�׿�o�����R�v�6,ȷ���T7�qnH�,��ߨ�KU��Q��e�z!�yMn�j`]���o/��;�i�XT��\td�qR���T�呬���rR67?_������̗ϪXkȪ*o<v���$dy� ���"��46�� E���/u�����]�-(ڌ
9U)���)�^b�� �K�j��xlzeA�`�u<�6�h$v=����tfL�\��mq�ڴ_���ܖ�"yGb��+]�&�sYs�_x��㫱!̇@}�jI��9��ni�U����ZpJ'�g�^� ���J�8v�&ܡ�+���6j��A/���1���i��P~�t�1ڻ�l�S[�V�&���@]�T�I|nm��fX3ޠ�H�a
{���9̴g!?d� �&wM}{�0��AW6��ధ�U5��RkL��n�V��q��#��+ ��(�Z��Fu}~�i�sc��r�=7j@����Ss��������me�"-ҕv�.����6�1*��uq��n����b?�ڟ�'j*�/Q��*���@~�M�:P��S>�Ӹ�9Yկ��i�m�qU�����'�bø^߇�\�$ L3՘�I�֬i�ئ�no��J$L�?~$fH���`�F$A����R�l���0�܇��+{ ��]�4�\+v! 2�n���@P����òm_�� T�!��Cj�V0݀�
�J�]���dH�}{9�HN���̡CM{au�h��3�f���u��|U�
.<�#[� q���D]��+�j-��2�k�s�l/�<�0�	zvkM��Wb;���@��~�Bj���`��Ǒ�:��%�,���˵��5��P����#��`d(`h�
&6O�Y\Q|<ﺦ�����69+V
bij��������E��%B��a<S!,��A�/���D�՞��o~���<��v��w�l���\a����|�
a��`���5$�|����K�fίc�������a�>��ReW
j�V-h� 
�v�Ya�}	-ĸ�p�o,yq-4Da���0l�hZ��<fΙ�:_5}Z����Y��
���m�G�+t��?�ڕ�K�2�U=��#T��%kSU�ۇv��V0�K�)�cA�(!������')�`��%�K\�=+6�R�����H�<����#+=xm�Tz{mbS(�q`}�E�9����>>hy�P���)+(I���L�s}f/w�O�p���7�>p��7y=B})H�N$9�+o�Ϻ��'0�3�s'ޗ=	�G\H�&C'l""���&4��i�vq�G�	[Rv=d�M���u;<E_��4�e?���/�#�i"q"�z��u{N/�b�)���$�X���m����ΣW�E�H��S��F+�鹵�/��J�o�no�����H��iD�����#�~�E���O��)��"}�0����ٓ��    ��a:���n�8�4������)Ѷ�^�ЃE�!ˇ��9�A�'��!�U��S��+Cmҹ���HN[��$�pF?�z�Yʊj�F$
������*�l���]�G9��a�C*׾j�_hҹ�'�-�_B�	���+���*��В=ɛ��> ���E �XM�'�k�8�EZ,@M��>�Yr�qo/�y��	E`!����G]�G
X�;�RѾ�',�y�J��Ze���-��s.甤}�.sP��u�d�����y���A�����`IQ��5i?�wCL(�9�߼���w�;G.c�Ħ����<^��B:"���u��t�yX	����]�ɛ�(�L=�w� �y!c]l�C�����P:;��X�?���8Ba��P����n��#� �m�[>R�#�k�~�|�LZ�.����}����PAi�C.���Ú[����!��2dV�\
w��ϔlȵt���8	�
�sHL�i�t��Þ���@*�,rdJ;+J�Ҿ6^�B���Y`momrn�5v\MNLd������2��"��(�@4<�`9����ήT3Q.~ba���!|7fq�G�tl֖i��>�Z��r�utղ���� �Ŵq$�����0�9�Bi�Ԝ�*�YPY����k�C\���r�Vb2A��v����1TVfa�fs�:mm��XߒK�蟟v��|=��CQ�6?U'f��rB\�NRҥcG����<k�Z-ܣm�f�΂���u��I�"��A��=_�=M� --���7�EX��Cҿ�s7Q��8(SoY���Z�˵�K�]V���3.�L>v-��J��ӳ���`�u�a3� �ϧ7B��6���"[�O���s�E.u&K�&�#m�g_G����\� <eWn�b'��w,t�>dV}�8���Ŧfd������!\���y��ni���<���T�
9���		��Fd��c�5O��Ō��D.�̤�E�w�ߛ�r�ﶍb��pq'c��mY�B(�ݴ��[�/�d�F5?�ο�p��M0
���7	��Gw �����r�}��E$��a#�0�f`4���o~v��"Uk����R���o��.�KH��~w���HI���Ɵ?��7T���ȷnV�4�E�R5�.���L�T��3�'�àLDk�]�'�4��IU }����$M9�@���|��	&�0}�uf�򄗔Yd�(�P�\�nU��f��w���h�6���/H��1܁Y���^"(��TR5d�0��������My��˂�W�K�Q�`��I������:��A�c8z� �eU��C5�!�������:���*.s������F��L#�5�Npa&҆1��A����Ӡe�)����+�joo�\n��ǌo�/8bǊF|P��������%�@�ӛx���h�˵N�� �i����Ny�
:!�V���3,I��h�%/�48J!�묞;S���Ο�T�c�|��R��׃;��1�h��b���!��1���,z�K{s��7;Z����Rg�[c}�h�s�h��E!-����U���m\�F�;�J���we��U�.c�� J��PH~D���X �<?��8����<W!����tI4�[qJHFW҆��}ׄ�|v�a�/ΡaK���j.���U���������=x�{g�l���(
`��B.��p��U��*`������Z��Oѡ�n�FL籱�<>b���zȾs!�qh���;���V�=>!3��sK\@�t>P�&�?��ȹ���K�Ązڇ�ڱ�h��مc~��UkU��Z/��:�f"�`���4�B�����u���|��h^g��Zeݺ&kh$�����ْ%���ݰ���}5�u�f8ж����3>x1����R�6Y��Y��̸��3��w�w��� ������ڴ�&���ל���M�j�I���ߺѾ	X��pn;bF���/�V�A5�;��\��%����x�i��:$�����	}Ex��;��F�;B��@��Y��ZWG]k|}�qs6���͒��
MWG4���=�]�/��D�� ��������~�kE�x%t6ƪ�~f��,�>åk�뺮^0�vhA�.��(���8�"Ƃ,��)a��`�wpsE������v��bWj��*ܧ����`��M�
���e?/ /�k��4e�u�V�W����~�J1K�7�"�(dLƴ�8.9�	���Ư��y���v�g����;*�[�ҝ6����8�����Ȫ�Qa%��60o�9���enhD���I�MG��${<	��,��>�&�e�y@a	9�jȷ#�BZ��je5��X�*�d�r��(�A
`bd3����g:i��ePW-���xd3l,+�XnpM�ۣy1&gі��ݢLQw,\�����L��%p�l�-8���D$�bS>ڲ�F ��!4>���Na�yX���1%B����ߖ%�����d(n����{[���B��rN�5�7?a��DW���|�/ �V�����I*�Qs ;�iD��i��Gol��� ο�i��,���U[��;�ͅ�@�)	�6�c�>!���A=�\逫��^��]j0�8d.y����@`�o�?y��aP�f��z�n�7��/o���/O�f�V�×��<�/�v�Pi��ŜY[&�EJJ��/? �$ωDc ���f֘�&�瞫�պG�\`D=�GMFN����{���C�Ą��g��l�.m�h���y`ܵ �]���Z<9�ݑ�W|U�6?\H��0Rn,����$�v�e�������f��o9�Q��&�D�f��}�M1^#2�Q4��8��J�S�ZQ��8wn�Uy��ťɏ�K���Oԩ�=�X"�PK.�͵H
\j�g��x�l�5N�������,��$N0��@��A�{Ҋj�rk���D�0�}�'iV9x�?���<�!I�YX��J��}�;�$���y�If%F�5��g�J��b ����N2�_�ꎷ��@��%L��$�p���.�V:s軼Z�0U��i^w:�0�Ʒ�4s�#�!����jw�|�$��QR��7+��b��]+���uys�����ҚW$[L�:��Ѷ��l!�i�+Udf�#Ћ]y3dՇ#˕p��E�iB�7����;�N�b%d�@�¡��ǎ�)d�d��?����>�Y]ݬ��#�����3ɯb�I�I���,S��#S��:��>2y���^�r�48��g�F�\`������F����hy@����inʕK��U~30�G��^8�.٫�6��;ъ��F��m`���y��ݜ.�0�!	�Y���Z����4Em\��Ţ�ŧʕ�-���tB,�v�����֢��#o�����*T���7{��ϓ��H�,8z�iB(֟ $�גD�$$3�q�⎗
peEU`1��"_�{f�"_pCuiS.��,!xsx�C�d��èO4�w�̨�����ګw�H��\��Qp�\�����]������f[vWcE޸��MAop��2;'Ů`oJ�v� �S� Z�V�^PdX�ˣT���~�����	"d�V=���j����t�a��QN�e�H¤�D���W��َD ��Н��~���8~#8Z}1�a0��<�:����n��V�g���R'�8�Ɖ�R"�� ��� e�a����+	ߛ(��q�U����2���Ω��$z��C���?��9R��Y�TL�������(K�6r�l��ϟ�c�q �7@`�����7�ũt��+�`�L :Q�T�3ܧ��R��uZa���E���aYf��5���2�ur���
����E��g9U��~-~�]i��/D�.8|��39|e�(.L	t(�"p�[��(`� �8�ĝ�+W�[�L�.^*W��L�p	��ST�߃�!4[�O����*�~,�'����ܖ���̂�T��U�}�
������ב�.K~F�ٳ��uؠ�z�{�:�&M4� �D3���Y���XiB�E��/��sf9Ny��#���X���    ,��M��� :���\�NK+ S���UW�m��<U��vxK�-b�G l�u����4�4d���g��Bc�:[�����SB�aܰ������U���G^��c޷�3$��ΰ�������z�`�s�l5��.�]���=O���m8��ql����eU^ڵ����7�A������J����� �E��F
�,2.Sn��>2u]/�)@(�Iz�	�{�O�{>z�00��I��A��4qY�kӪZ���9G�%_�ݙǝ$����a;B5@W6��5�%}��Z#�A�����x�Bqd���e�>��Rj,�@��M��SUy���;�gL��o���Z���G���g���]����8/�ꒂ:��0l�c�4�9�mO��k����u
�<w���<˄Lc}4[����U)(4Ȥ�q�a퉠�����c���?��5�������т��?1g� Ȇ ʋ(sM<�FMcf����O�wa�;�;��Y����ϣ��iH�g�2�y����ՑL5x�s����k�d�9�BMe�QT$kB��<�?�O#.((@M}�@����x�^�25�FK?�{c%�1Q푥F0��Y��I2�9� c�U�ѾS�7aY��ZW5���A���S���aT�e�J���(k���"F��C#��?΄#�Cx�h�c���R|`�bq��v�ʠs�ɭu�������6�qy��;����b�R�Y�]p�P&g� $�/G��
��,xfa�ڦk�Ys�gՂ��$���砻H O`A����:y}z�����f�WfF4�	�[�#!?E�q�C$5����77y�f+��.���Ӝ����4'3��t?C�pb�����.�˘J�1<#k�/�^��(k����|����ѦΪU�|KU4K��DR��F�G�/�G�������W4�7Qt��C�k�sc���U���׺��+_�/�+o�|Ŝ�>bԞg(���6�O8A�v��@���6�S>s�t���iU,H��k�x��";�6�=*y�ĒV!�}]%Fu�-�C�䮴�Y�u��t��1/�f��<�����'�cl�y��إ�w'{�bSj�R�@������Q�ً����3ĸ�Ȭl����9!�0�iJ4R���NZ�T�`"���v���U��j���t� jx]8jy"�~�p��p�˅yB|�f��B۫��:�ooKU��y��{�R-��1��|�9�N��`��� O���4�� ]��0�e^�PUy�,?�y[ftL�܋��B�����-F��\2�SY�t�S���k�kkIt���eE��$��R�!��L_��{-�W�	�U2e�Q=�wF�7tפ75h���WZ׫̔��W^�_�W�$��H0�B_����@�}��थQ���.���Ȳ?B9$�s��=tg���b�2������u��ҙT�M��7���̶���o�NU��:c��h����g�6+V�:�*�����)�$U!�#|�v�0
������ҟE���BE�L/����B�m�,\�/(>��/s��L�ɶ�����m��î�dh�� �1��Y�t��$�ʶJ�N�>/R&+Y�(�U�=����*�2��f�6[������|��{�yd�D�s�Գ` �W�z*��nAJ�i��UY�}%;�gh��:TS��S�0�D��x��k�� )w�oX�̷�ߺ��(����2��cd,���O`�eN�#1/���*q E惤�*�)Z�|���>�7����rd���-��/m�����崚"���|/�Ck�c�V$���A����ݺ�5_^�|`&�����?N\J�fk̈́o?h=����Z*�ֶV����Wk��*D�E����x�h\y�2ҷ%��I���^�j�K�.�t�@wU��k�<\keiC�wdݢ8:
'9��O�����I�ч�밽=Ypk��'��ś@�_�x�y����^+i�&��'��^_8�Ꙩ�ы����gyW���[0	�������N�Mx�E�"S��-���h��h������-S��g02�����gC����ĸږ�Dj雇����EF�0W� ⿺e(&�R�:O�NAr��.U���?�Jq��
�����^�n��~�$t''s�2�v�8S՘2�}�P��80:�No�A��/\A�0�,� ���uu ^�;�9���S�WX3�,p?‐�e�Y���fB���(�8�ͷ=[Z��+�t⒉6&aӚ`N?�`�d}=��t�Vn�de~޸�{�ϤC�_�����ϗ=��Cz�OB�YQ����(���$������2���,�'{���BvfrL�T�|�m�e��X��L0��$�G��#ׁ~������',��Ɓx��nG��&�����a;T롊�F5+
�Nվ����;En�T;6a�S���@P3_Ί#����u�_�]���F+י�+��6�7Ѕ���b�K~"s>�$v�]VT���~#qR&ER,iƯ�ß\X�EO
���-d�����GQ�B�1�L�`�O(=���8�ý�m��[��1���P���M����������ά�AS����1����Kp�]|~b�2�����:���p P9���|O��͘���;��NC��/{V:	��ɤ����	�,g��{���8�:U��)�[���h'�������۽�n��B��Ö'�_�����>�����C�m���^`>�AA=`Y���27�����Z���Qjm�ϕe��_�|	C�gI��s-����b^5z;VA�1�Ӱ9�V�F-���n��:M]�EJQ$��逢D��`b�=AU�i�W���ȩ@|Р�O�Dy"G�W�j������� Gǉ��\�tlO��,"'9ʇ�P*����͢ξ%�a������q+�L�w�9t��4<2�h�|�#~��g��$X!���]
>�4#5KƳ���3� �&�u]5�-�������{�X�OX�"+{iy���-�
h$ص&�����W[gY��j��CER-;?�Pz����|#�kG��<�B��J�N3���iYf����nwn3G� G��\Hx)5S��p-x�bT�X��\f�`��&/V�D.z�.`&j�j��6�0<=�8T��G+^j;8��2p�kEX�W�[�R��c^�䏁�&�,�3>�G�,~�����V�Z9��ِ�<7�X6+%Ve�;4���ɃԸ��h�D9Mb��w��<_�z�3e��u�1�&��a�&�f���2��0���HZx"���y&���_�ݨt7��"�Ӧ��۹i���!��Uv�htv�`Z�"PF��y���hh�E^�G�2:k�%��]�K�'B�K2=��ڨ��[��/�B˃u2v&�!��CIE���l���B+�i��/�?
WGqe��31�84.��qؤH��b��]���,��x������}�f�'vG1t�]�s�̣>��!��_e'�\��@�_�Zo�d_�� ���"mNc��2ީ �c���Yg��u_���i��sS�u�0��	 �����z qx�����!�k��
��v6��6���J�T�;�����f������rC�ǈ�`���ì�#o�Y���z��v�]r�����@�h-&�#۱�D;�gr�"9&�՜��k]n�*��K]%'I'����;���c� It�+$�=����cf��6�Za����d�ۂ�ڰ� oxĵ��BiC�+�8�Q��ĻF�4�2D�L����T�zk�xݤ}y�Y3Y�Z��M~&���i���b0&��gAɲ4�֚�Z�݂��eν�v�G���G,)j6yf��� ݐ{,avH���i�(@���4��s�z!;�����&�F ���7ʙ+1*y8�7F��SpX�Q�F>l�KH�s���F����t=���Jo���#��I�ٻnq�^h8��@�x	&���;��HD��d4U�\�tE�ߣfɍ�ߒ��d	و>���]O��31�Z���Ѕ]�4y]/XuXu    r����}����~D7�=���Nb���Cw|
�E�%Wp>�7�9˳Xj,�WZ��to�Fcl8T*�����~w�H����O$�q�׍����dtk��e�q�"�|����ڈ���Q�i
D�^߱φ���,[����f��v��q6lI�N>a�C�4�D�z�D��U�w����4%Ai����/���op�E���V�,5%�o�^ivˍI�w��y޾�h�4z�Ͱ��W�����v�P8Z�bV�^a�Ŗ��Y@��:���ɏ�yfq=707bt�e�;1@�1��gX�{�Η�0�T���*�	�n�)�f�	��g�ߘ�9�W"O�
/ډ�_��*�~�5d��*S@���R�nM�Y��՞�+ @��ٿ_2�ƻG'��)�,,�e0��G��l7b��w�c�L/�!�*�K�6M���L6���͘
�S�� �.�L�~�F��7�΅"�Z⊽��p����B���"�k�ƽV͒�:+y�SYn;����c�'x;]m�#b8g��8)��l�q�i�D�����S���=�����t܇V����	NX��o^al�VB�%#��C���&�֤�	�������|��yH��Qk�㴪O`�}m�JOd��h'D*	Y��H5\xt��p��Nű���)��&|=|�r��<oڋ�.@8%� �3F�����l�_�i<W/AC�e��#�q�����6����no1����JK�������?vrף��X��E�{�.d�(B��;Gui��o����T�W8������k�󽨔ƶa���Q��q�݉��<mw�}Ĥ��yd���/���m�*��^�݂z�7h��:����"T�U<�1��Ŀ��Pa�'�X���%?T�=&@J������r�NΩ;�]=q��V�i�O�0�a/w��u�D9������}W�4V��q%��(A&�g���}ۘgZ�ߓ5+}@tX`�� �	�ɤn�۷��x���Ǧ��&������zS�׀����{����?��#Ln������I��q�J;;k�l�Ьu��ݻ5	��}�1li@��޼��߭�|?�$`Ą�����m��?�i�[��:�P�����[ c�%��8�6�,/-�a2������u{W�,o�흭 ivsp\���t&�x:m�'\�=rq7O4��5�������K �H�q���b�t�VVk�����]{!����5$�/?���T�tF�����z���%u�%3�+�n�*ap84�ay|�yD�!^ �<<�?�N����;�^��/T]�&F��^�o(��j/c�#��w���v����K��L24����=�����ĥ�x�i��=�u]ַ�r��Y��/[&�dR@u�����|P0���,(��z�b۪�v��_8�>!�<#�������X+F�g���]&�ix5t�+�Z��m��jA�u��up;���EP��hQ%�R����Px��6����1��o�x�d�A��"' 82d/v"�yf�Ѡ�3
�����$�r��`H�5�u��0<x������}�)9���@�@H��)�/;������L�L�����O��3��N��g�Ğ��fs�*��yӊ�!�E��J���mf�(_C�Ǎ�D����ә��'��%��Tb(p�WN���$W
E��+�������T!�,\)�f��c��l4i�iE��Y�
�VkI
�W����Щ�Or����B|��#ʠZN���B5�se�җ���ﭭ��ˌQ9�鄗���ɰ��
r�q��]$��q2'y�z�M���o�V��YVw��3[�㘙���#.��H��׭��n���@,�F.���87h3����J�3��]���qb���o���hK)I�}r���>�@���+��?"��N��\�e���ia��\�����L �6�z�k�(Z�#k���Þ|]�UDĢMNp"�)�P?&q��Q%n�k�u��Y���U����� �ň�̜�����CZ�Zk����0�e|�uB��p<9�$A����wzy�9�������߾�ZJ�������T�Sz8��'�$�C#(j-Bv�R�P�EZ�L&��b�����Ku�ZP�XU��9v�v4hC��M{b���z8�w��=�j4��B7B8Gh��&m�{Зq�f�y�֦�oW��Y�>�J#�NgQ��wH�}�g��)�ҾN���� ܲߠ��K�39���ˎ�Yi_��O.$)�r���X�'�0&���應����Ґ�B�zC>���5ݑt�h>Yю�z�ڿ��h:E�թ`K2R����bLR��!@�K_��h��E��}�棅��mR7��83uY���B���<Y���XKA�ﳣ��Bk���i݂4�J�䲻����u�>�����}��Y�3S{X���]7�\�l��/�u�@��֬���l�L�}�\&e�б*M"Ğ*»XrW�0�gWb���1�s�Z�]��HW[��;�G�"ä7��GZ�S�n,"�f�,�1>a\"���#H�{}1��ڳ�!�b��F`	�dXЂ^��˪�[6�v����t�g����mK�.��(H��ky��Q,��e����B��!�E5;l������~�b�;
�q�ߡ�!�G��������L2�q�r`�V�<���#��ۮ��`��3Cy�uD[M��Ԗ���r�UPeKu{�XfB]f��B�LcE������c>$�e�f$�7$ٽ��B��eBH1�c�1k�{x{_m��L��Z逮�͂ʼ�MQr]T�	����x�����u+]�����1V	� yU�w�ʑ�Ȗ��W�.���Bb��k/�5hz%�P*�����ۅ�O���e���B�<}U�H�'t�a�M�۟�tf�̀M ���:2b�Bu���v���<[��LI��
S�m�	�׶�(B��n�|�,����r8�c��/!%J�$Z�l�U@��$��j���7;�e����TץI�Y����D�p�G�Z�'b]N#c�ۛ��aSU��>d(��Ġ��ɇ�#O`��	���p����l4}�v��g�z`���5-�f�0�JQ�Щ��笈�.y�������$�n�^Nܳb(��X�E�Ycˌ���s�,dM�2AEE_��z	�I�Z�5�/p���,3'��L>���I�8����4ۓ{!�ڑ4�H�{�ӹ�B}���֨r�s��U�-�yŒ��pЊ��%#0���	Yh;�B�$MV*i��|���e�TQ����%T�%��9r�IY����pGS�KYg��" ��"qf�FL�f��@8���ʺ�܂ЩT���J��'��^N sĊ���=[��"�cķR�f���5�G���D��c:ic�aڝO !�&C����AƅFt�u� ֤ѥ醀Dmc�ug�,[��gIzR�¼�t�Dܙ�a{�9�Q���	�Z�T�g�*c=��c��aX�L1�#U�x����ݹA{|�oRG��QK�%������8C2����U�X���@
8�(*%�I�K&���I��Ѐ�ٌ���eʧ�U�:�k=�]o��	�����Z$�}|��	�>�E�)Δ��ֵM�`b~Mz���eQ�Ր�J]v������|��q�T�����L��H��s�6���,38��l		&���<�B�g�-J��w���u;�&�Y���4�C��rɓ �>L��tYْ�E��?���ZGy�*��5�|�\&�%ʿI�Bi��J�����-�����Ҭ	^��z�P���>[�V�ʷ�j�Q+�,���%�3G�L��&�\H.���Y$K;��1�}?VkV��R���o/c Zf�+�w=$<2�i2�Ƕ����Ԭ(�w��8VY�7�_���r�h��|���4��������Ǌ�%�?�a�c���H�R�;r$�C�rC���"�`FB��]/�`u8�ei�Z����)���]��4+ �,y`� -�g	 �Ϳ/�����
�.f��?���,ny    Vd�J+Um�t8U��>���3	��wG ��1y��%bݠI��f{�����	�>����j���6���������$�c���=�"E`�͔�YH�̚�
�U]��8���ߗ���'r�")�{�O�u��*9;3�5��P1�l"��S�J�t��qE�qi���P�I�<�E;`��($�/���4�u�g�b�0tYiU.]��js�\�@��t��l~?�޸g4J[2�ex]d+�Pkmm�.��e��L"�1����%�O�E�D�aS��B�6]Zv7�'O��r O�@���{�����8*�OÓ�&��*�S;�5��ӏ� �,!8{@�2�ߝ�Z_ Qā���(�O*DY�&n,� �>M*���
8�`=wa����,ęIӵ���e���7���,�<��G,*˞v�h��"^��0C٘<�ڭ�
���in�se5�lT��c��W(v��Gؐ��Z,�:����@g�O����2P5����Gq�(�����=/�c��ʋ�=����PfX��6�rhb��p��q'V ��D�ej��DT÷� 4H~U����d�׷�U���������=�pA���J)���hЎ���4+�
��=¯�Ү�_)�'� wߦb�5���y�Vr�7v�b57&˸W�M�	vwt��!��q��"D��B����dF.��C����
����^�H��r�9�Ѝ�H��������d��I�3���>��A�] eI{%B�={�������;�/`�^)���]�-8���2)�\" '�ʳ�ב6�ˡ��Xj ω&w��J��F�ق�G^������?]��������"����Tf��*��������q��8ki�2K���@��Lv��UijS���4�Z~�&�458����Ka|���� ���U�7g��Y�����s%������w��=�w[�����{�	�L�䇁 w���m�~��#;�N����j�и�5���S����ɽ����$`�O�X��y��(%#	RM�M�x��
���?a��l�a/>��ge�֪�ٔ�w�;k�n��00�yy�%L$0�0t�GcÊ�v���=)��B�L�֕NS��Zp�)��VE�t]�w��3q�Hc{/J&���~BI�Y���m}��J��z�:�M�z��f�n����ɔ-L��Q�%U�m޿P[�3���^��f��Z뼶�,f�v�U��_�|���&u��D�w�����p8o#�	�s�iش�o��{���fI����̭U�&�V%�Y��G� � �����
?_-_���+j��4bƔ:]�ΧM����hV�Le�\��%��S1��}�K����p��*˰����NZ��|����W�݂�^�*u2A)"M}�9A��G�ZN��X��`1�I������J�L��u�i�������b����L�NO��s���q��'��P��k�Hn���F�e�gq-�Z��\����D�:!G�"#��(�(�T�={�X�X�P���2Z�5�˱��L��W8[�Q�����&)2�C$�<�L���sE2H�p<����P���ٌ��3	=Sd��[)[�u�^0(rXs��/�c;��*{�P3�]��Th�G2����]Y��D���ۦ�u\�V������H���\��?o�T����oa�}rm[�j���tJ.f�R&ke��K��[B�*
ke��/�OL5	ZhA��sD����?�IM:
����\�٭tpҶi�`�^h�ɪ&a��;���=�����9�ae���6'F'�xi���V!m��O�Q����&����[`#U�wKuH���7DٓE��)v�)0��?_�Y�L��v����ko�,B�ʴ�:h�A��F����̗i�=�	������ �xZ�|�8i�Id�Ԇ���;!aLM1�tɀ����~`��L���F�HJ�ˎ,�!F�pB��'�����I��������"�	�c�D҉�C��,��;ҷ��v��)'?6�@�n��5N�>D��j�L&����n�����	;�;�#���D��zm���l�$ζ��lAN��HgQ&��P�9�8)&�҄�� �I�{�y�`ET�l:�@{�<�4���-�J/w��}v{_[8���4���F�z�ou������ ÷H��^ul���r�0��ˑ�^�˼R��}�N�͎d�ٮ[���)d�3��×Ǉ�M5�"z��; ��a^�8]��������\Q�y�#&�'_�M���l�;�%y�z~5K*�L�9��J�N��-x�J�ïUB���=$G�����A�b��'�����)�M�\�vEV���\:U�݃�.��OSAGtBwO����mcD��SЍŢ��`�ȘDL��I���}�`-�Ӳ���!
&�0���hPKd���Bq�k�ѮN�l���
e��^�(n�H�L犩�ڈDE���&@�r���P{6X]q�,����e)�s����m���鬀��:wU�i�r�ͳ��2$q ?�k\�'R��y���HU7p���L��M\a�ұ{����d��I��{�+6���1���s`���>ze�^��������NK{�K�!�=���1r��7/���7i��b�¢g�v����BnQ稦��ձY�N�$!$/Β�񉡄���d�A�-o�J`�O��d=^|���5%��j���\Ĳx����9�s�f�w����C�V���V�N�eSJ�q�����)cs"�-��6���'4e(�0]�^�!�e��z��k�핯V��/��Y�x����ߨjL�6hSS�v@�ÉedN���Q�x=Q�.��J�̮V�+m����
Q�0i���"j�	�/Q¼��3��2�����T6}3K�h��aw�����)]J(�fT�%�� ���"'�����5�I!�Q�]�5��~=��yV���3��[�L�$1�=jZ�R���>5�x�l�BH��/��'?ĠhX��L�FI�ߢ�&�Wej)�E>��������}�&2�n'0��x6ׄM�H^`��TW>�ę"s�0�"{[��f��)�����8�0~�8��A�D�i��wK�\���{�J�E�ٱ9rv�U���nW�Z��tji��s���g�Du�)��U_h)�۾��I���g��N���?`'W�Z��f���}��=Iר�����P�)a�����_X�ߔ]7:�1��_? G�	QӍ��
1�[T�ҵVBm�/I�F��� s��x�3�5�2'�}��n�������lS#�YF'��ӎ��2��"R��=$hw�_H)�r�t��*�I�:��u� ¨�����$In���0��W��ֳ�L� Y�:��MF��]�4���<�16�0Z���%�@B_CT�� 'dʠ�M�*��`�Y�\f�[逫O�~��[;[j��.y`�grf3�EN�ξV!\'3vј=a|�bT��y�lZ����}ֺ~���T����)eGA�տ/�p,��G0�U3}b��|�k��-�u雿��*��*���s�W96$��:�#�"�����w����#������Yl�9��@)���$�����7��݃���o�MZ����xȄ���H�G�gL�h[�N��`�K��W[���n�H��K��&KS�@�'������W�1$�s��Ɗi�JE|�f�*�|���^YU,�f�ŷ�~ߺ횊X7�Fd��E6����⨹	wj�������A8쏎��AF����O��d�M^MA��!�kl}&��
N|X�^����˞�qW]w��Ҩ��ԁ�|�4���d��j��(����Ǻ
q���b�_��z��Y�~o.�#5�.� Z�d(�j�^m���n�/]��J2Z]n�����A /݉�M�D�ɩ���L�\o�{�_�Q&+�r�"I��ݪ�+�ʈĽ�v1M�I��xIl��jE&q�!+�Z��N��0hḴ&i�Y(��굒p{��E��� ӬN�y�P\�]+y�G%��_4[����(=0��mV[��߷@B�w��r�aM��^�9�)3�;~�5�    ��8F�<E�x�h)�ʬ��חY�.�Vղ����>*��^��:��H_�µ#* ���6E���jK�U�WՂp��V�K�����.�/Xf!�����A�޴�89��ڈն����6���8�60P���������	yT f��� ��ބ&�<S!�-~P8�GO�O�+5���h����yu��ܿۙ���K��R~���P��>��8��"/Q�� tϻ��)��H�÷�{��[��k�qY���e��k ��J@�P>���n����[��Z��4�����`ͧF,R�#�6{��t��S� ����J���Y[tm����.3�J>`*¾u4*!�~$�5T�	�El��8��/Y֪4��u�/8V�����O�\�L�i�C��#��H�!y6X���lfZ
���}��-��,��:W��JU�o�kڻ4U)�Ɗ��<ACM��$[۝��46M3�B����W��yM��R]��8�`�qhQ���D=�}=�#�8����a�V����R׹E��E��1r,�:���;��s4�>W'�G�~���4D]��_�<j��^�м�ͧh��9=+�#kV����5*�� ���ۂʇ������U.�sE�#�juڝ/�!�z���"�\��?E$
;�����|N��ԬT�7���R2�pA=���E��j1�f�"��3�3����>���Y�o �oOW�p��?��2�	*��^6y��O1Ĉf�і�"ȩ�p9`���fAqD�N��?GZ���r*�u� n�@s���c:NCH�����Ħo���|�������@)�Y�ܾ&��T�v�]��<]r�2e�a\�
��D	2�c�tEc��3X�в��_ZgՂ��.�e��4P��!��%���,h�^��MMy�؂��1�Fl�IYb�E�ґm�>��xɀ�	���Q�v��>�����{�;������c����+��G63=���~�����>�чeZM_��XS�p&w�_H.N̔��K0��� �"��F�'B2|s`��kE��G�G�6���cg�ρf�{DΠF wa�ʀ���?S�RK�,5��n_�Z�frY�,�,� 75��Jڳ�8��Joۧ�&�gI�m��hP�Y:�2��a��o*��j)T찵�EJ���u�2�����ôE�9:
Թ��K˨d��-	�졕;M�q���?��2Va�Z��������ҥv�b#����Y�[��S��xf��$~��]<�#9i9mK��sښ�Me��DU���;Rh P9�^�]�������u�c�+=R�2��ݐu�H�h�H*$�J�d�ݎ��=����ĉļg��N���͛�o�l�	*3k�m,m��_�W���Hs��<A'�L�Ӈ:�'�xC��t�Y޾Y }�M��5����8��'��L�7J���*p�9"lq���O���B�?��ק#Ws�(�ԗ��J+�L�͂���r+�ye������&�[�� z�c��� N�$e�y�,f�,WzE����1��2�Ψ�=*��t&�K�[܈kV{xu+Nؗ=��{�`��O!���n���2���6�1��}
#���
���͏,2�p]�4D�-6��?١�%#�k#�돕�Zq1�?��8�l;��Wq��MH����qj�9A����#i���E�5�[ѫ����)��W�oA�F$�v���'?������A�lϔ,Tkܬ7ѨoD�_��ݩ����Y^�^lS�tl�R��C�%���}��/��@��:�5|z��o��~"�t,P8ԡ���*�2�ٗ�J��ϫ�Zs��k};��E�8�"�MXê� �1�9�:]��}��4�Yt�ܤkm˳���L;�3��Q�!�"�e�x�\C�/ޑ.��W< ��yx���,`ZY��tE�$S�^�9���.-0���{�;���Y0�
�Ybp��\�
���	Y�LXg���uw�v��A�ڬ� 6MY���;�M��:���!�n�i�`�E��=&�:i�Ϻ�n4�z�υ�7���"5�?;�TWZVu��CF�0��_͝��(/.�(!R�]�,j�w)kmU���͂�Ծw����oa�z�*{ܦL�
l��0�mT(�N��>PD!]_d����s���,�e�gkmo����	��d�I,� �rŅ�`��-	A:��c��1|Q= 2s����Y�3a+����G|V�K>�L�B���}����t��R�'�ң,B
���B�֗�"���,&Y�<�Ί-/lcn��J�Y\�di#���]�رg�4Յ��л�s�m��X�DU��v�-i�L�=ៗ�3�=���;���~����EG��FoVL�,��k��0�
~*O>�P��9��6�O$J%Ѝ�R>q�F���/��ؑ��������_W4�l�9��X�u�TϪ�(�x�� �<dfa�za
࿜��������	�,�P\g�:�w��;4���z��r �h[΅)�97�!�� nY����1�pO|!�3'O�-�Xɖ�5;tE��JkL���+�Rq�,2��h�a���Ǝ�ߢt[�a���,B���k�g�U�Pi���9�eE�;.΄�%x�Tx(T�?��H���@E��w$��������^~��+�$gy��B���	Q'�2��Ȉ�1�Q��Y4la�ꏕ孫t�����ҙ�aD�F����&e��&��H��=8>���|�ڈ'	Bd���r��FD!gvʕk݆�]�.�-�Sͻ�"�I����M`��X��K�3�=�[�ƨ�K�RG�Le��ycl��,�,Xde�u�ah f� �Bel#�L#���gPn�V���*o�4�=Ty�1ܥ���}�2�M$"+��m�,ξ5��͞q��$Xp �䞭[�:����&�,9��u����V�A[	9��Ķ��I��aa��d��,&���Jid�C�݂��:��+r���TO�Aw��������
�B�,/���sH���'�/O;�� �B#�O���#��*ƀF�{2�'O��s���<�d�؆�*hU/��}���F�,����8Fbp�>�M_�E�D��-e�3�������Ŀ��@�H��xy�=�˄�3>qO���L��O�oSW�o�������L������E��h���q�ĕJZeʦ�.b_m�.��#3�+���m���:��rfq�@��)�j�ϓ&Ĉ>U/|��}�,�,��NV�mۛ�}Pu^��5�2�ErO[(�ΉM��:���?����<��Lgj���ru�.��i�	�o�,͓�`��!vȐ	Y����OVK�׫�grx��1Qh>����/�̫��(��N��;Qog/I��Hȏ�bW�=���AuԈ ^-t�����*u�E���	��%�~\��,]i�*��-8�I3�#w�y$�� B2G�c�ɾ�����'2I<�b��,�<(@�^��V,��+��>�H�ۮ!�#�54!�=3Pg̸l9���C�a�W>��(�%4����0N�a�P�.�������Ծ`��c��QwE꘠�/ߞ���]H�"B�^J�̋�Y���#JS��T�~D��
�J��c��"�O�I��.qU΢$ 9�ǉ�K���@4�3�0}��k��]빮�-������^�$�/v�t͂N�H�6���"j�x�|��.�������(�������d�����y�l�[-�M5YS,5�k�w�k���9��#����X..<�K>� C>u4x&��x�g1,�[ؾ]i����-��њGZ*K���%m�`�K��`�o�"s#�|����l��i�[�2\fAt��|�w��\���2+Y��Py��@�^<1/a��r�:��?Z7p�m'+_�R��Bz�I��}�eJ�H���(\����o�=���J�$x��U �X_�l���$�u`O�y،�f�a�ˮ�}B��*W�]�"�i� 	Ŝ�:#�	���~����A1�[P{>�}n�H���Gبm`��[�l��Om̂ ;Q�*�N~`]�<��!˫���x���߀}`�S+��    �
��.�^g�����~�#�	l�Еc�KR9 ,B�JA?r��2��ǞU�M���z3S*J��������L���<�;��.tW1�q��v�渫;�f��
��ˁ�m',�;�"�&��|=M�����lh��Ϥ���<��u��?wV��.�Ȏ]��ߟ'��[��{>_�9d��g���u|��.��K�H��h�
�R����v���1>�j�{,��nG,��25���gm�	;�$��y�ʬ�+�J��*o���:�S)�[����&�qf^W�F%h�6���b���m �O �Ok�37F�u%_��oSf
����he��Hu#s�]7��m+�'oF�۠���9?V� ���z��୿�&Kך�u׺���R���^�f6a�6��v�a��Ou�>*�F�Dz�h��_�t�������}��]Z�%_ha'9�����.>���P~�H����j�V��b<
WWV��QW5E�GH>��9h���cO]�J
�Vo�u��B�h|�ٵ���}*/��<5k]��S�RV�*
��NW/�����Z#��#��#c^y�;�.�?��/�~� 9	�9h(Ntl}����n�?C�Z��6O$�`�I}ݲ�{ǐ�%Ɩ���E"�P�Hzn܋���}=�JTӃ�
�>���	�^��G}����,��ULr�յT�e��A.�%�ɵ�Y���˾�z�q���G7��v�!AO�z�` 3;��hf�Z�s]�KJD�k��.�"y�Q���W�Qܺ���ZN$%����� ���_���<;�h2L���/��-pg�rf�y�M�%�a�+yZ'`�`*1Ǚ��q�Op0��؟ʖ��� l�xe�,v��s+UZϊΙ��y"par*M�+/�0q$_�`��#���Ȗ���A�l�Z[���5��'O�Ԥ+^�4K��<�G��o ��6�ΐ��l�.�����iE�m�n�j�琳�e�oVzou��EAs���s�53'���8�@�umh��*�(Y����M�?���(�A�&�(�/���D�i���X`�d|�I�@Q1��΢����Xi��ɺ�*��پN�w�N������rc!g&��m~%0]$к����&�F,��G �D�,�%�b� ;Wd+MZ5M� a(��qo��� ��@��g�?_n+�kF*�sPedC��Lڪ�6%���v�.Re���[�C�Q���P& 2;��&ך�@7�o��H�b���Z[��A3��NN�$ [��?��f� ɠ�s�&0�7�O��Jo�g���cH���RU���N�)����L���ȥ���u`��r�'�Ȭ�e�y�O;d z�fc�.�	�RG�=o�/���PgiQ��nۼ[�p��f��B����Τ��Ip{�y�h�э�"���� s�5���E��5�v�mn�s���r�L��Zl�v����0*F�7B��<��;!�f�r�l�Y�}B��̬�t]�/H%Ɨr�l��q ,��W /�3���x��O��. �Ln�����������wpS��-�Z�պ���v�\nUʩt	�e23e�I"	w<����R	�]b���n���*���B�tU)� ��T咠��'"��?h��:\٢A�W�B�[7@�)m=ܳ�¿/���0����(������g��om�0�h}�!�9\��,���LJ1�8�x��-<K?��U�~���`�TR�KD�+#��ᵄH~53u6N4��Hz���!v���i�.3e��=�ا@B�:�e�ʰ{���b	���_j�,)��v"�bR_^�쀳��?OT��p�;�9��I��0�(h|u:3�W�������]��v�u~M�|����E�lB�������kH��E���'�nm����Fwus?4���/�ë�Y�̭�M���]�6U��5�G�����}���d�+��ͯ�}�vl� �B
�e��iNAU�3��6D�i�V"Z�2D6EB�4�g�	��8H�y�ņ["i�������[z��L�Dr:U��<�N�f������ UV8)�N>I�D (h>?� �<�b>W����q����S�^��1� �Qw����_T\D�+���K���3�\�ڀ��	�pP�ݮ�53Y�;� �&����Q���HcB��l_�j�i�!��E�R�H���Ɖ/j+�a��p󩕛Q��a�\�f��^�����Y���|�sT�2=bܮ�ǰy���I��hS9�J�\��펟҅^�=�/�
.�|G�(�0�gq�@�6D�W=z�^�ɆD��S�8�-T}�2��\�T��%��X6M>������ ����]�o��d������B���k}��K���
!w�,� R:���	hʯK~�2�T_��%�C��S�=��N}����S/y�n��6O��	����wtV4P��%�l7�;�+0��5=Ҍ��*��d�yb:�2��y=�q9��#l�Z+-η��[p2�*'_JW�L��VE�t �AB�|.���UNQ#�Z���׺�?�!vm �Yl�O�k�p���*<��T�l�JT���¤�c0����F�d���`F���2!�"�����f�2k��?�2W�:��$,�d,�R��K�`�E��.�Z�Ui[-x&�$��g�A���'�����Ʉ!*m�'��d Z=��y��'�}DŅE�z�]�yE�Q.Oy�����#{�\��ٳ	�P�{�K���"#�{�Н��XDBd|�<�&��<j��uNM�evAcW��������%���(�����rk- ��ҷG�Hӌ�m[&�wA��uLF	�`��v��CSfn�@�6ł%D�jI�.�'B�(=�'Ho	�3p|G�C�J���L������q�Y�#/�_@M�it��ӵھ�����,S�_�A( �$�;�A'�(�W=�����E��H��mH��<HxoGc���ɽ���
_�|��������'QV�m	�fD��htm���z9M���ig��_ش���Q���
J��<p'rG�6{f��D��#�T��TA�f�R��xX+z8�H� zG$�]C�P�-��NUO�8��07��qz��A6�u~{�U(�	����7*�<.��<���7����j�ؼU��`�E�x%�Z,y�������CʼO;vAh�L�\dB���{~ 4�w��j4 �E�����;���z�|��$柁u��MT�&�5���X����8�& >뾢�==�=w9l�'$�TS_L�pd��f���t%�3ڍ�P�k;u¾�_&W
h���x�>)t��A&��7_nd�ڮ'� &)2��qw`�3iK�����@��(��zg��xN��v1
��ݡ�����	���*a	�kD��&��k�E����~ο������3��߃fɁ>~6H�9|E4$Q ���G@��}�]'%c8���8Y�|�ٞ5}�� Ud$+ߓ�mI�t�\ӚƩؚ�eԕD��7����ĺ�D��V2���b����1��5�7��[��e�� �@Ƭ��~vN]��:�}��[�ߚ�����3k�Iȼh?�T�����*��s�
��ܬ�V3�[��)tY�r��<2%���ɣ��y?U���ҷXm充o�s�wd�>W�.�+u�ҙ�5}�@��?�.�\�BR�Y<��iʖ���al.@"�����3��E�6v�,�����Y~�s�r�R�l�i�+G�+��¯*�г��O��˦j�J��UM� �Z�~�J�>���Cs�B�k��6�e� �h�����c�/��t1!O8��%�^�6��Z�_��fA�p6�N�*!��{��TI�ŉ�/a��=e�n��Q<v�g���k���u���|iL��_Y$_����y������E��&5+]ئL̂t���n)ѧ�u��F'��#�P�I�0�N3��J	��ufvPg�?��$?ь1�aq��Gt|@6L`X����&�:�Z���H�a�+� ����%o���P�tfJ��6	j1O��<d    RX�+-�4��m�@��8�,�	��L*d��׼������seE���=Ɗ���H���7��"�E�8����t����vI:z����k���.�tA�J��p���a7��1!u��%J$w��-\ժ/X�$�&�7��fqtά�������~�����_<t��2ab3d<�	�-˦��N�H4u1U��]'П��-8y�0اC�0h.H����"\>L���-��aY�o���(v�_�N�3�f��"��Ǯ0����I�k9�kA����k.T�òj�����zD�x�G���m���4'�\t��(���<"f�\��t4��V_�E�m���֟n�J�dD�TT�����|��������+�6}�"�i�2'��*l0}��w?��d	<�I����+1�'n���Y��by:Ϝ��<����&!҈*f�����a�cW��7�kZn�J>C�N�$���/��U�ѧ>�ikx�/�̮҄�sed�+�"]�5ת[������"������5����n���p���I�������3;#A�GF�6�/���μ��Λ���ܛ-�m$Y��x�|�@l�$E��iJ�-Z��kU63���R���q�=���췄�ڦ5j�X�WD�vc�_J�2���T'�h�A�W�m����l���L�pykL�E��g<T��b���ܢ�z�m��؆d�q�L��_`݄���/F:�8��=���`lYX�z�Ж����y��9gr/��&_���c�;��w8T6��_�`�
&W{�GuM���ήul��J�Ս�Yਹ�h\��l9x���ɀ�v���X&'�j�S9��hEەN�\�\v�Lj�x�|�d��d!RI���g�?��
���ih�Ϥ�E���%
l���4s��&-�[�N�k
]ݿ�0Y��ۯΰ��ۏ:y���o�`�j��{��l��x=4l:��,�dY^���ϋU,�+K>����Z���#Ɠ7U/��ϼy����<T�h�֚6�����=�*O>��"l'��0�|��y��>S�Ҩ�;H>U���b5��4GG%�Ij�5@"b̆�p|�����JT�m|�w��� �,|$ǰ�U�����Q��"_gE���&�ܵH1\'�TI-�-"y�uT�~�^���.�+��+m�B�����P���X�Q����y����mb���R?�oQL��3� r�j�[�����	�����_���/㈄0#��*�"�R�Aܼp�45\x�Js�y\�yiG��|��͂����y����hz�QҢyK�h���H�� ��Y��V�X�-Z�/8~&�XD't�,�B�������W�1,�!��wmC�ƨ�6�
������2�Ƅ[��E*|Gf���Z{N�I� �C�͉�1�h�1��q�^i卷��Æ��U�&�	0*Jجg�@����FG�)[�7��Ջӛ_�hY��վu���@e�gv<}1��:��7�ԃ�[��a�2��˺՚�yW4F��_�<O�w��~�c��iO,ѭUى�LN���E�P�n>2Q���UL�ftJ�kը�^�tAC��"���Sx�$h��\`$���v*��)6�U"�LWV��8�'��U��}�VՂ"�kg$��A��{��#"� ��뵺���.q����i���l�<�Q�E16N�6�C��ͤ�a�	N;������d�K�A4L����M������:D��І��EEun�������}����M�Ȇ�<D���Ż̭t��U,x�m��r��r�|ݙ�DDT�|9����9\i�}|D9���c���t���\&�w�.�.ZK��R���)�
�� �~ߎ��~�hjfa�|ޙ�} #��X�^X ���=m?��)�D��yH�Ҽ��|�|jv�e�{DP2~���eÍ:�'PgZ����oJ����)�˵�d�1Ȩ����ԇ�3R�,�qXr����dD	!l�HgP�c�[�(���s��^팮͊(X����ԹK "r�~d�Q�L�>�4��#��@Mp�c�1�2 t�<S~��~ە�w6����Ck �9>�p�m͸��SLT�C)8dE�y�l��觗Z��ֲVqǠBwFO#��H�a����Ǒ=��EI)��J�2m�%Q
!]�ʒ�L2b��X��g�����#�'!K\�q��$ɭ@Ҟ��۩�9��ʿ�"䋕0e�E�ł�BJ�'߉9q�*�XC���g#q��A2���:1����&)g-4Dי+�<�j��I��(P%e�1S� L��| �%(f���*<w*����g\C�=��Tgڹ�.[K��}V��tqL���3c�(������M�Z�FʢRf��g�L��bغD�	��Q֐9�1y�S�`7Á$�&�j�Q�l9��Cق��o�`h�iE��(�S�6�g���͟��4��!+�3��fdъ�ľ^��U4�������VP~�gc��Q��j��"~�Yer8��tL�C$@\��w%+��:��d������[�F��b��T'���w��֭�F��^�����O�g�$_I�:���� �c�{ŧ����b
�C5��a��^�qFiL]�a3�J)g�o��M-�&L�DS��m!Y�D��	f�}��$yR�M-��k5�.C%�,x��b�o�;�e����)&���%[}�!t��227Z�֪��|��?�;��U��kH�,�AS?���=���-P����q��|���w�ln�+0`�M<���[��"�۪]0���9��"M�G�*6��y����$�A�92�CF-OQH�Yļ��j۴�� ]�S)Z�,��Ǧ�>%�����D=�!�ˬ��Ϥ�9��K�43+eB�US���1��NZ�"y��3�#=(���[B1E��,,Yf_��b׭IM�������(�t`�h���/�	�#��0�7_���"MX�	co����v!�N����WqT��Z���6�E킠�L�^�(�7�n
�a�N�ST�߼�OV��N�48h��S(�]7�\nW�];]-�wJ�ٵ��7��%��+*q�����CKԼH����Jک�95kaV���\�����| �*z�¢8��Mh2������^ؤ�]��Iw��n����p~Ǣ#�����dу��O<=�'9@(��\{�wR)m� (	���}�E��W�:W��^�Z�LQٺp�[����qLј@��!��'��1���X�¸ۛg0W"<�&�J�K�1��<
.|h�n������S���K��-�es�-9��� �ES�������{�ɴ2>_ �BN���4����f��d�dt��o%�4�����2tR��}���5��� �0�x�y�N�.�_CR�X��@�O@l�7lq�^�O<2�[��Ū':���}��RE�� �k6��j���!�x�F������$�qK$k�Aɑh�P$�tOSDG����u����r��⮃;Pd�@P�^ӎ��[�|1z�#��>$y�}<�<e��:;� ��k�ɡ�[`4�r�T�CI��5~Y��<�H4��M���-�B�}0"!���v �����;o�xx��B�sU�u�W��m�|��fi�6����N<���'�~��(oم)#[ �(�``?� ��Jp�3�	�z�/2�g�<Q�<�Ox�1��;�E�"��N��QT���/�`2#?B@H��ԇV�e�p������'���,����	F�<n�T�`c@o�,H&(����Y.�85Q~����V�]K�ԛ�I�p!�b����1$1��άe���븣pN��Os���V�e�G�+֋�Z%��~��d/�"Fh�'�%�u"�i>��ܢN���k��WHoӎe�\�ӇoԮ�QU�E�?�Yay5� ��v;܏xD��ĠCҮ@
zj��4V�rv�U~����>O3�K�Ф�F	������oH����=|O~�ܝUMf�%a	M0���I�'���&��P�f���ZB_G��G�;Q\g�R�#(���Z\��F�����P    k��Mk@N�qq)ϗ�M^�NF6U��,Ť���K(��7�����3Vm�ܒX�4���VQd��u�[�kK��P5_E�=JT�:蟸���9�Sӗ�.�\�:���|��u����y�6��f�r�`��S{ѵ'��ik�DY�C�����'��r���,R�Z�K��&���x�����O�H*x�#A6 ���,!Ҵ'��_$A��^ r&�K�FY�_�$m�}���,�&�k%�ՙJ킴�s����d�D�9�X�����BӼ�rlX�b���ED�������w����y�0^H��HV����~"�>z�!�^d}�����i<��[���T�7�Z8���V��U�/`�zS�D�(�>L܉D{�AM�
�[h2?���n\�3bOiy��Ψ"_�IV��rI�b�j1E򚍅�3��Pyƈ�Hh&8��*w��A?���ݫ�?�z&�$A��f�=����IYj��H>�6�ز#�f+B�71$!G12b�!�>ކa+�פZJ���� �f�o�+�cѧ�}t�!��7��n��u��67LL'����wX���ͮ$�����(t�����(ˆ��v��۞��Hlgf��0$�C#~�?�^k%y�E����b���N�Nn�P y8 Z��=�^�f~��t�}���u�2�:B�wec��~<����ƶ��4J:0�a��p�1���e&\�fs)��ֹ:��]"��qlˮ�M��9`Q݁���"1ۀ�|!�������l��Rj�(�Q���D�s��w���Z�6�U�ϣ�q�t�ql� B*�u���}w\�\��6.H�Nlii�&�v��I��I?@J`b|�����v�'�e]�`�O���gG�"[qv�"��/H�B�f)����$��"���V ��c��Z!^���^D�{��*godm��-��DLyS:$n��j�l&�a�?���X�Lb����d�Jg�����7{���͒������Q��LƎ#�����\�q]�Y��k�c��R���"��>���ɻ�\49H�GPB��6$gR��m�L�Z�.���zI��1�R�#&�A�
-3�.����faq֯���UhCXr�
f��#x�IK�� �MEc�Wo��� ӵB��)U|�b�8lw�Cc¼X�<�nr�,x�Uj��`50�g�f1�`�h�nqd�#�K����j����]� P&�rk�o�������ٺAO=U�LY"���^��I��#v'�� ��ڵv�m�ߍ�,2h�_�����4�^��*xp�!/nH�f��Lx�U���1b�0�'��,�E��Z��ꮼ�����L�X4-� �8�S�뙧N)O$��ೈ��0��9�GQ����q>���Ǎ{��ٖ ����b�����!/vx����b~4�Y�m��Cl�iK`���w��8�c�sAǜ������]�3��U��Ɋ�^�_B�r��!u~O ���0V9$��.�p�J̟~"|L8���'�"f��"�<�1����\Ը�H ��j��4L���fܴ�~��'�,�V���������8�x�j�/��0j���l�#��%�K�׫��DD} ȕ\~��w!��4h��Y���.|�c}���Is*y�=v���0m�PT�3�BcU�ە�M�Z��B�^�r��W" Z�в^m���"�����ʺ"[�l��&��W�#^��]�JW���Vd�B��@P�Ƕ�N��F&�B��T�	F>��S��Xi����o�O�|8��B���7��1�HnK���zf!�ůP�*����bJ_�V̡��]Ұz��_u7d��v��V�k����U�!�N�j��m���',K3%�+璏�6��<�~@���T0\Ck@=\��w�H�u���^��۴i0�4��j����y�.�qV��7L����k�w������ؔ���P+g�
�x���������,����䟇�e�	�)jo��m��!c�Bt�6�����$9�*D�s�,Sj�4ʦ4ES/��2�YBrQ��f{��L����f,퉻x�DuK�	ou�L�	��C?�WBpKR����<����,R)m\�<�m���Q��Ú+t��#�2�<���:��ԭ���S���ܩ������s1�b�&�Œ�߷��1Y��Cv�AO�!=T8�~l/5�)���bl�l�`��n���)e�.�_�ڔ y,�!��x�n�Q���YhT��ZQM��*�?4�S=(�U4��(U^m���&$~܏|�W���	t:�5�c6�c��NI2��P�Tᨂ��Ӏ� `Ǯ�C�"z��E�yx�D�3� Ř��^m~=A���a�7��F5g� �z(fC	oDZ�����O�ݐ
��HP!�"V�w���!�����,y@�1�8�/�[ ��,qKQF��a��=�h��{V� H�h!�ip�ϨSj���-��GVh!x�|QK�7��R ���՗����x�i���[���j����L�N0��&_���2���p`D����޼\���z~\+5( �b�3��	A���;ob���^�'�+�Q�����_e}	�`Dى��T��\X� ��U B�1ku�j�\rA�qbd�}�œC	�6�C�ni7z�nGk��)i�t��K���n�|�����3��t�;�V�2_B�
v+1῔+i�u�G SY��h�K���L�Xr&kr�VZw[t�j���)K~g��Aa�.CQ26ph��Ű��/��5�`����LJr�kl0Z����km�,O�>����>�(�?;�]����P�`�����;�-�LX���;B0Dk���{�i�S���Ѕ�Lxc��HA`�H2:��
�3�j�j�$���J"���t��zqo�������V�e�=pL���/I�Hq����7�Ė���,2Y
3�uv���J{�*"�C�%�I _�.���e���<�!��܏�f2�d9�=jh�Yu;z����J�قS����$���0ʮ�Y���!�D'`��3dk�ﶵk�����;ɚ�&�nY�H6�$'*���FL��t����5���ٰ�%������swy��Ri��U�m�/8a�.RI�.aA��h`�N'ĒĽB�V��׳%}^Y����wY� �k�3��� *;|#��5rG5[\��ܕ��]�]w3��PBr���d�y�1:?FE7�DXB��u]�GP��(S
N���':z47˭�?a�1�}�,�4�A3�ĉ"����Y���V#�C�ҵ���yTǛ��-/�gZ��=QW�G	�qn�[N��5���OG}A�Y^I4��3���|}�QP�+oU�pg|��.�P�n#��"h��a9=]y�5��vv*���0�ܩ̼��� �|�1Y���߻�ZP�1�5R眽���O���Js���Z��%���=T66��!0�W��qV����,��qPY�1�Ԑ(�(�"E��N�y�K_��}��v�Y�4�J^G�S�G(�s��a)>VמPپ>���QW��EJ����֪׮������n���:�����?�T1��J���ssoS�皬H~�!�����R6�bZ�x&&G�G�9����B��5�ɮ�z"�4�^�¬t`ޙ.[P��T�F��(�H�=�We�5&f��$�QF  �)1f��M���t�mX�ʼ�?��W�z)oL�<Q�����%[����
t�q������U��MBg��
�Z�tWfՒ#�k/98�j$,L.�yڠΒqe�����"��|�ց]e}��T)��sh\�K�Q�Ř���c*����,i��@	�<|a��&��g�N)�ӵ2������	CJ��L�4�a�ډ�����f���B��Gbt�o�䒧����Iw�"	w��Z������9>�y�|(C�$�V�cO���+tz�;@��2@��޸���Yޒ���� �ch�N��Nks��\�T�D*<S�C�G{��3��A���*����7d�Ҏ��sB�fi��F�l�2N
y΍	��;    7�}dIn/�/��
Mo�Cl1f�2�r����gkA���K�+�i5=��4 ���v�����#]@�[/O��f-Ʃ���!R*�
k׹��S�8�c�!���fl/%�p��tQ��:�8��O<d�Y���*]'$~� ʠ�5�Hs���GSG�H�R>��ݛ4Uk}�Lє���"�^6�I�cs���P���hh�ϛp��P��y'�}�6� ߲mt �"��v�H��d�\��u�Y�L�x�B�/ "�o�ȺO�^`�8s2�$I��T�֜*'^С��O�V��3�&��f9���3��v��T��LI���4��y������lp��ؗ��Y�I���:X�McW��!O�b���P��R���KK��h^#S�� �6��TF�Ϛ���> O����sd� ��29A�si�Af9e�Ya+�x@�E�;��pO��F/ֲ0�
��a9*��u�a��vAY[>c��Q G2}&#���� i�
�b�"q̞�O؊��ĳ�i��f���6�rCAp��a?b���y���-:4T �2���V_�xA�6�־�k�i;ә���	?/�J>�~�ҕC3��o�@"���_���B�;,���p�a�/���~N@���=��ʵr�U��i,��y�![�r��APC����)O?@��n"ʖ>��6��J�,׭^p��N>n�N~k��?�U���*+/2j��O����A󦭑j�Cc������sJ+��-L��E�������"�X�� �����8�3(���V���Ss�,`^�l��L�mywzڬ��jYB���W� ������9�H����l���=>���]�L�%��,_�va������t�/At�'�1�%�%�y�^�&-���X��#�wG�*�������vdUc��7�-�C�����G^�Yi��� �}(^�����`1�"��6�M�9�u2�B�VtzI\��)ym.D2rG�a:GCd&W����chM��V�(���9�9^�L�e���(Z���޹�»ʎC{!�z�� p�v�} H��/�'ЗKִp6hG��iД��J�
�����ʕI�'_h��*Ml%N찆u{�vdO��v�!'Q���1�,�3���ڄ�_qC=�McY��ʬ�2�}�`E��+�ɅU�?ʧM�A�A�p�.m���� 'ٹ���t���j�ڭ��6]��ߙi2�vE��%#��<BK�(
��Iـk�pٺG�����ѬtD��u��M{-ϜN^��']֏c�5���@��5C�ҟ(���H�5J����݉�uD�c���C���N�vR�V:pɺ:��Mi�������BI���y2�K�Y_m� A�B�������c�'���.q� ��4z6T�k�^��E� ��4e������K�� ��4�@�6�K�a��_�4m��Wꅓ��ł�ιH�)i�\���\X��f��	E�l�����Z��\�L-H���O�
��c��1�0O^��C��Ɍܢ�V�t��Rl����C���z�
W��O�B�2]�i�~�ۏE�р<q�u"�P�..�#F�j��R���|�i�L��̮�s�5t��;�\u&��ۉ(_Ԝ��2��a�r�a%���6�@��㯴͡�pke2�g\��<�*�:���`��E��m{���;�d+e0�F�qO�H�&+��ḱ6�T�M�jů�Vɇ�~*Iȳ[Re/A���W>�$䳇o�fq�Ƭ�P�>�\'m����d�B�\>�P��11�C�Oӵ�o��O���� zSl�ga��ڑo�j���2*�dZ�CO ����NrT��F�+��d�ű�+`���M�n���M��r��t�}� b�q,�������o��Í�j��C�B�v �S&�H�m�
�֪���\��P�JUa��g~�h��h�t~e�ؖ��B�Bxފs�	z\��-gA+�­uY�WZ�ea��w�ɪ>��f��Ih.�7�t��A^����@�汲�.��h�y� O2�I�O�>�瑔�N�n���/xʈ�9AxY��z�?DN����?���,�:���֩I���g��I�Lڅ�'�
�����c�7��Ϣ��p�%X�TKjV�EoRjo�wK��������Α�?���&�.%��gA	D���w�)�D����<�U��NXډ?6)*"G�ڼ!i���{�
���N��zwx����̿sȬD���W�w�]P�/�m/�ǒd�0�>�H�c&|��4��<�]�ip���X^��ޫ�w�lDM���I���Ʊ��I�qݍ4O� ���g��H����#�N��t������!�V�	�5�j�먄J�Xqk�y=��pe��=A��r#���I��}q���:�*M���ƢR瓨��p��������Iϐx%l�PO��3�T�3<�&������ �9��/�kx���K��'��*ȸ��.<�IU���js����L�*���Ƨ2���`oǇjfޣ<I��ܫ(ENj%�hU	�n�I�<�>W+�/�U^�%�H��6��$ u�	��?D��!~���1qX�{>#�:�W�ǐ+�܂�ͦ�����7��8�T���WH�<n��E~.�i���
%�(�,6D.�K>�v}��H�f���&��0��E�~>>��S�^�\V�6���tj|�+�1B�qw	�(z�E�t�|�g�>�[k|�r��!}9@6M��ڤ�=��IƟ�܀�jQ���K�C�E�WԚ�ۋ���ɁDIR��x�:-�JR�Z�Ni��5�6QDA�e,�z�l�يw;�����JmKrUfՂͷ-t!>�'�ٶ�4���!nO�L����b�@(U�2�th�V1�C��rp�g����=��R'4�yW�o��e]�X�8�Q�!��W���
���t�K��|�/�W^�Yb+Ţ�r"M��c8̡}kB��í3�F�"��<3e�Y4!k?������7�N�-$a������4l����>���7�a�=7�hd����"�t��IZ~�Q��'rn$]�j��zx&q�Bc4�~ ���u��r*��dO����f�7���ZC��܂&��e2����qL�C�܂�#�'0{���/�� �ǒ�B΢f���x�����D�����U�������k�TbMAn�	��y!��K��XWT�i���c]!Bx�x��O�#r��B�+
Mn�/��E��ܘ!���0�� ����|[,(�|!�%���{y���h�_z6�S>�1���CT�>��˫̯�%(Tֵ�5���ݺd2\��#l�L.D;2d&��m��t/��X/�^8$�gM�KU��:+�ҕ�C?]VX1B�>�t)S\k�t.<qBI��S�Uq�@�Z����۳ `$C���VpF$��l����T�� �������rj���Q`]�̆��nƞ�FAe�˿`�B����/<��KS^��"������;��jo]蘄�h�Ռ�iÒ���'@-mI��\nb�J<\jZ��L��@рlϘVA%>��R*_딩�Y�i � Ի<�D�o��� ����^M>E;��ͧA$�,��������g�ƅ�\ek�\Y�n�c��X׸���Z�gq��9j��gr/6ǡ{����H�s.���+�2���f
ֹ"yǊБ5X�� ����c�����_���E%��I���h�v7�[�_ϡQdfؗ�v���*@���@\��~���n�=�k��C�#c��9�*�Ēţ��6����IZn<;m�w�Έ���Ӟ�M_m���NW�>k^��M(�5O�=`�����	Q���Y�������ʄMST�O�B+�*��:�v o��#wZ�S	%4Ɯ4)�b��l�id���ygU��:�*:c8��F�eg�o}���vG3��Ķ��0}���k϶��'�&ςw8�[r D��Б�x%��P|]ꪵ��:�z�˅vT�	β�lEI����W����j���.Db��Q��,|��j��uق띸\�Ҿ��৾���b[��EGD�����b,�����~G    ��0��;=��5k���C�W���ا��r� \�o��*����'���*�Uy��!6aP���I툨�T-#��XI@�i<}xv�Z�`�L^ܿ��Yj�����1L,'���\zh��6�m��Zᄺ�F�����*�:Z%�)�5�L��c�h%;:V Ft���c�-m@fE�ϴ��Z�E���<�++ �3��Z���D�y��r+�Gk��� �`�#�}�)d]�'BL�B��J�+����߈y�����*��?2�0�#�p�/qe�Z(k 
wS9��	�3	�$/�Pb��a�ޮU�L[
�aty&g�H�/B��n��{¡�����%��<,�� <��n*�}�VƑv����e=~6Fy-D��f;:ָ�z�1g���A��tBg�*�̘���t8�݂졳\�5�k�U	'�k҄�7�9��B<o�����62��D����,��̩���ti��-$`sH��eè�6���p%����7�?�I��4�MG���G捄�&O�K��H+yK�,� �	����`0{� �LV���s����@�m��kHZ;Ǝ��k�����`@" �`��kK���gҨ��i�'!K�U@��9��j��j�OQ�x�/����g'D���e �D�ǹ�z�y(O�H�O@c���kXb�w��B���mC
�e/�QY?���)զd�� �Cc��)6�K{��\���R���ި8
�.��3Ęܲ7�aD �sL���y&(�d��r�R������)����_�z�]�.xGm�d�}�VcQ��˟?a/��M�۶�]���X'D��k�(D�K�pACgCD��mɲ���z�٭se������6��z=����S;�XG� HbnG�mg��h5)5�V{l�yݺp��z�\r�u,N�R8��M"�;Bv=���[Qm�1m�s}�VP�o�$�����XB�R����'i5pq�k��=���exy#	���n�"K�֝	�d�iƸK�@���/���5a�~T�FV���}-��$?EV\؉A*s;0lH����0̗|*N�¯��s���y���2A%�ئC�.���F�Cp���C[N�O+�s�n���hO�9�""p�'����I2�+@�Եp���e�M��'ez��eNHK���V0DHH~x<DOa�~yOX��Ƕa���/9#2�$�:`?���ګ|�c�u��7տJ��)��J��nH=�@5�'B�A�#�^�d`*�ZL�Z��D�+]��vu}��Ly?�d�"LN%u�|<�X��%V�,:Y��j7�Uj��e������oP�`&�[6��A�	�4DX��=��q3�j�=La˻�U!n��Se`�.X�@`kxnELR��	�D�Ǥ�&�k��{����O��>�`��:e�m��:�܂���l������Ľ��ʏ�X��G��İ�Â9����f�$�jt"ow&��yHm�VRS�v��TE�� ��I�c @��.����<V��D΅����Rw��)���Uη�G�Hu.�؇�����dR�4=xߡ�ۍ� 2l�S���Ϭ���ćg|iO0.�g��I���qii�B;�<�,M�B�"*ۑ����/��d�uC;3����\UħE�M���5]V��P��֊Ͳ�_�u��/�H��LK�S\F��>��~�j���3��ίt�b��r7OQ3FY�Z�|&��d��ȸ��1������E[��t-`J��i��Y<M*y͋�)Ń���W�e��9c}i��}��a�!������@u�h�YL�&]q�;csAo!I^^Yp�H�p �wH�cb���|r=4�{z$�������W����gb������p~������>q�d�yy�R'��>�iz�\��P�g
�TDC�:�`�ܜ�����p_ß�1Q�wќc�>BYJ��]bG��D�,<�gy�p~�ڝ�c
|��y~�M�ҵzU�JW�Tm�hy٬H��6��v�C5��e�5�y�,�A��:��B?W�13���/w�k��ݝU�m��q�J����Ƣ����bG���H�!׆����[�[�@�:4�۟۝�9C38��f�f̢ks*W�F4MZ޽�Gt�(���$b�!��ʢ7?[���d�Yj\xz%k��N �.-�[W��&�#���e
�|�3PE�[��3�.<���x�����)���ƭmJ��t�I�d&��wI����5e�3'�i���H�kz6�q/�Vz�uբR����'��g�0����ۇ6x�� T�Yc)�cV�E�iY����,=�Uy�Ƙ(��v�8C�	�p�fb���40Y��b���pt�$0�`���>�:b��v����|B䋄_ݟ/� �PY��cs[���HYV)�Hy����#�&�@��6d8|`A��~Ck����g�
_n���U���[Y��&�G����ơ�$���K*e�@�K��~��vސBrۯU���n\��d��y��2�Y�m�c�s�c��l�H��;FF#ĉ����`�鏫|��*������M���t��8������7�h7��8��y�T��ZU�QM���)�Ƈ�$_4@k p�D#����3��O���.�#%�%�X�T��F.��-8V�Is��s������l���[d��9�<�a`2��f*xYb��d�)��/43��\��qO���,��n��<�$/���Cx�[��4��2N�h�A�̄�т�0G�c�-�F&�<�d�*8�AK���y�\%"y�:���������j����
�R�������6�J��,������t�fy2ך��~�'��N�G�|s�$j_>�� K�V ��J�.x�l�
��By0�Y��&���GM����C�����V\��_��
��!4�٢�;m��)���e{1�b9����Q2�$d�->)��~����obb�$�2�,���AP�;`�2(L��C��~�r�$@B��L��OC�4<�;��(�G��,��j�^p�!�9�<���B�ó��g��Q�0X[Tֿ��g���!.�`�{e��Ԝ��̪­U��6�)��.�e�C
B"`�S�5YXG&�XHFUhب0�Āȸs7W�Sj�
���|���{8ws�T�e�R�MO`7onS8�p�
!	��F�ƠE23��폻���d�י�\Z���[�<ՙ��=��CxpE�F�ՐGr�oQ%���b�J��M㖇�ڥ+��.k����>�f[�t2e	�>�ݯ�f�1�#�� 	$��C�	�8��ѭs3�6O< �C�t���zP���0pr���z�y�AoP�� ��,/y`C��2m�B�4\��`�I!@��e!�.&� ���*N-��6mx�w�6�_���ޗ����ɉH���fA�"�$z���y����Aû��/Ԍ�v����.�k6̂y�v&4���ijV�Wou^�?����!m�o89�aR^���m�=��h�/�J񯮰K�S�ʍ���&_Ű��ݥ��If�����VJ�W	1
M�+�����QH�lZV�N��D��̂��,]+�̙LU����~T���.�X�>���+2�)���>Q�+�R�g�W�������R����X
��ah<7����s��	9pB�a-�W�(u���=\�/�0/���M[�os/�b/�Ɋp?H_�	�����oE��+8=T��������fu[�v�O�NFY�������C�Yyzs)�?��G�.�KdJJ�H�5����_�x��54Z߄/q#B�%Rg��j��a��.��@� |�}�T���+��al��3����4߀�K��(��,n:��Z7k�U6]�
�T��G�7�q����U� 1�)7x������]�w�Y0E�rOD.�P�9Nt7�	U�et#�2��υ7�%e�p�>ˀ]��2�£6�ѝi����6\q���E-� ر��Q�,G`YMK)5�3xD�9"��m���y��F:�K=�[H5�	�?1��Vt4ꉾ�6�x��/��~��E�YD���;?�GB!Fw~�}��u�|��T��)#G8K^��g�f�Z*�jvI    �0�az�ϡF�=��YԌM�Z�\�����5�RYZy��h<��bD���ؑ�#�S��`n���S��HK�
��(�Q�g���S�'��2HC�}v�n��м����e4��
��J�ā(&/.b[4����GK��s0I	��CH�NLMX�S�?�oC��܈��[�R�&r����t��VP��.�G��>	���@�Vl:(���i��X�汫����e����K�^�d��{-l�m:zlT�� ���D)ᙷ�����Z;�6O�����k+�ҢE>%b�cPN�%d�����D��T$�=�)��g:�?E ,:���tg@�=�h��k�T�b�,�,$���iHY���R��lG��ɞ�S��-��I/�8)�˸b_°$(�pE�� c���8��a0� ���Rx$QT�s��L��?ڰ�Vx&�
0ԕ�d�Bm�ƛ>�!rƛX-��$�M����B�����N��g�*#K�B'�S�2b|/���3��N&��_I,���ȬwӅ�q�i��N�p1_)p܇���h��\	��0I4'�t>�eA�|�=�mgV�Ќsz�q�g��?_�<�FBc�7,�u�3�@ׁ�ޱfԻ�:0=�;�3mr�r���t��w�'�t.���%�OᙤV���U�^cm�aR]�;�l�rbT�UIA�� �RVgk������+������=��y�b�4���5�[���D�2��1���,Z��n���C����&u��4�M� '��Q�b��Oz�{G��A`����`��`��^��^,����[�ְ�i��� �:���'���Q��|�Q�Q�8��B=��r�6kAS�j�+���s)�����y�H�DO�c]vZ���c�5�G���˗ �,�Q�߯p���):�H/5*�x2b$m+��O���yEbc$��Ү���,�������t�,���#�N�냈�‷��ٌ�4�<!�+�N�,�k�m�����b./r7u���(���GRj��50�
�����QĞ���o���"Zk��-@�+o�B҂I��-��bd��M�:!7X�:�$o�3`��׫}���,i�����oe9���O���[^.���+�@�h�I�o2�!!TҊ�怀yӈi�V��[��X@0*�~�vɧ�ہ,�I���W�/�3�" cg��T��veV���{����W��'��DL��������"�:cqf�	Y�V��S�O�O��ʄ�e���?!������XȘf�.���$��]�6��a-O%��:�|^���|q3���C� �V�¸5Y�.j^�����n�F�� ����(��
�=�+Y_xt�z(�c��Ȇ"s+̔E�����>�'��SF�G' ��+NZ��'8XT�8{�W���2��Fd����`2�:����X�dT'Ǣm�q���y}$�#B|�`��G�t�ǔ�]������[�D��D|%�S�؆"�V���ϴî�v�`G��d��FfE��Ea�JɊ@�WZ���U-}������#�EƁ�y��.�yy�P���5���k>y���2�fz��<��Z�	�]r�]�2*�W&��"E8�Y��r�S>�$P<Z7z ����ԭ��e�v
I~8yW�佸KӴn ��˴�,�Đz���:+-z]��Z� ~hiRF)�m'H��&{��ً�-;�XN�'��GY�=`0�PfY���@ ,��D`f�pɲ�{�
+�hCH*6<�S��� $��Ю��O�r��L0�	\D�����E��L0Dbn�������	�%	�A�!�<W�(�2�Z��Uuv?"�0i�h!e��a4� e�~�Fvi����|� �rFEѠgG���Z��B�P.��֩�ф[��Ƚ�-�l�ٓ�=aA�UH��:��o��6!��*_��%.߀��f򙡀/La���6J�epۅ͢����׶l�P���#�ˆ��N"5�Z~�B|gQ��_���Y@�-��X��moaG|{�"6)�Pw��d��h�%�Z~C��W�vPSE=0ϑY�o}"s/�;��¾�S�W��L��tf�F��i;�8
���[��>�=lO;f��ƾ�W����p"8���&V�9P�~�^m�O�ưČ?3��{w�B�x��
K�`g��?��e&?O�oɂ�Fj!����ؕ2Nʲʻw��!3>��7SOq4��^�!�CL{��g�q�KW[.WN/P��r*8�&����BB�,�ziTtYI�=\)M0��d<?<��=��aΧ���#k3o�ZW��w"�U�9�,�J�;b/ʕ��$Om�G�B�sS�UL�l�Y�rx�d�o���O#�������@mx���#l�<uz��� 6]��ߋ��DNƪ�%Q:.���L��䒦���42:U*]��r�����s=�"!a��k$�M�"�.�f@X�����u\{��!��ٚ����q�uXW�v�a�
/V'o�*4U�NiV_"h@L�ٔ��D����	:T�W�7$�,R M腷�,&c��i����6�qVd�Z7�Ujs{��!�&�$�1i8���� ��QZ0���9� �E�s�_6��̸Vp��j��D(R���h�a��a�\�'%�1�m�X�)Prh�SϳQ�����*W���U�ba]�(,!��Q)�L>�`}j���DPM�oT���'!�K��Zu�+���Z�BI=T�O��b�4�"`�����oX\0wu-
ו��f�P.��̥�x�@'�'uD��I��W�o8v��M�v����I��;=]H���F0�C1�����m��S�S[/��:Վ��_���M ��ֵm2%x^$U��q���u7fq
��Z��+��ł۪m.�)�syH]�[*y�'y��eq���4N�d^�����^� �P�su*	E�w�݀��L� s�hY���clf�j��Z�G�Y#c����YC_����B�����!mS����Jb7|,Y�݂�'�'p��P7GW��BRX��>x��EZ�Խ�6uYor����E� �����w:$�ʘ�2�=`��X���Еߍ�p���:�5y�>�#����346�]�KX�E��x�P sGz��LE��gmV��Q�e�$@5.s�q��Q�ZQAU��%Er��Q��ǁ�$DG��"
�2�:�1э���B��Y�B�
���`Մ��]5i藤�s�0x �%g���l�1i��b�����uq��e2e���|򍈮���r@�,�p�����������r��
�����i���]�i�au�d��u��
�������Ԑ��� ��(Y��%�e�<iz�t�<Sn��������F�y�Y�4,ޖFp��B�L �A��J����f+�P��nN_.Ny����>�3�ϓo'08{��}g�%��P�
�4��<"ީ�*�֪�U� "��������b����(�tR���Q��E�wBΏt��J^x��N~Vc��Z�YL�p���Ƣv�WX�V�� 4�*B-уo��A����\�����J[�Z��Z� �O9n:y������
B���dU���W�����uN�24��f�s�K�����26-<��(�]ސ�jT���>L�:�j�������*��4v��;I9�`�G�j}�Bg�I�C�-�)��4�n�����?a磍�1рK��ݠ�����,�5�X@K�	�����+ ���9�4�|,[a
��gy0hZ�s�����!r�f�І:�-��O�� ��c`��A���?I$|g�*C��A�}�n�	,�Ce�9a���mK"�1j��`���3Q(�!�Y�Gv]��	��S�j���C�	��-5�$u�dN�P$�5{U����<�̮uaX�<���9�d��.�G�$P�A]'�?��r4,�&��٠v�$�ʛ �H�kA[��ֿv�v�H�K}!���@��z���F�ə)뛚�%���}T����`���|k}�ɤ�o�4��̆.x	�8�    s����=��EZ��d�N��l�q�xiˢ�+|J_-X��2�%K��/-_C,/q�Ol!���e4��>���LEd�̙���+��#U�v �x�ɉB�Z{��D��16�0q+D;u��?H�t=��#��H��#�\��7����y�h��BlT�V�@]�-��[x�9��J��B�;g0�"�N����\oI/���a ^
Q��G1�S��yL^�1�i��׊߬��o�1u:�S�o�)Z��0�y �P�&Z�_���U|�I	���恳�����m���1+
_p�4Xϴ� ��P��.8oQ�{
q:z�z��{�C" >�F���Y�̔�kE��]Z/`��<��W�¥�N�F�hl!rW�{@ew���H�u��k[ 9��HB��K�����)�i@�D�q�s�J8��e�P�\��v���"��"ӫ��k��u22xb�m �x��xq��dC��Q3	�x��rV,�Йa#˛�t~bEF�
�A��Lfb�	�	�N��@`[C ��8�J��P)��{t0De�2����iR�n���t<˳�z��V�z�!G�U��~*9�6��Y(��8%P|?���[	�<@&3�J�u�v�D�UE�Kfq	)�?�Gc��wvF�p�N�lk�S�������� ;��9�e\�#̂�r�Z�f��uU/n�;�sp}�<�䈍�>,�
�`�18~��σ�'@ّ�Q�7�_d�	W�@�P� �0ۅ��Ap�ר��
���ɞO0�2��	L5�����"Y�ܝ{ʓ��Cz5�����I��A?������2"�qF��\���t!�f��xi�2��1�z,u���P�C�|l�I� �'l�@�<崀��Vńcv^�v�W�Z6�î��S˥{�&�p��&����Ao��$�x���<8.s�J�[ �JIH^�eβ�J0^�.0��F�����C�ճqE&�#JfDuMè�.�j���Ե�O/�IeK�2���G��S`��Ŵq��u���� �P��+1�m, �nth	��;��a>ŵ~+-��.�8[�=�']����\�3f��^��wy8�ަ�l`Hʃ�<�)�Z+�1!�/(m��$\E�	T���C��I_mr�K*�d/3��#��A��i�"�\���G����\W�9LǧAƠ��m��4�1��*�?��(g�ڼ;�u�O���8k��.x����| h�u����بh��=��G_�R������bt��!�smen��&�u�w`���L
b��G ���m'�� �y���,����,�u��t���Ren��]7,�N^�<N�`�����cx+C�3�B����X)�:x&l�/��5*_��u�lg�Щ�b8�&a���Q��[+��v!݈_V�O|
�6�7�I�`M!��G�,�.�ڭT\��s���<6�"n�'I�P�D\y�R*g��x"<+f�v�s�*fq]��{�g>��렐C�����H����9�O�^P� z+jݙzL^U�,�c<_����l�M�x)qq,x�7v��!�~έ���j����/����'c�����qx��<�BF�L��ÊdҞ���N�	?�=��Pq�Ê��h�%q������Zb���.m�r_ț�w�����&0�ATK�jؒ�|z���ES:*j�$u<\(��Z�ț*���ոK�T�?�Pؘ 4�I}$�/א�c;��"����H'�`*���ԭu��T�v��i͒B.���'�a�'�f���A�%�N��xr=�x�C��r�",�i�\Z�V;�����~�Ih�S�a�����i���¶�ty�t��V q�C&e��ei�֪��4�^�=��ư����Z��r��R�AX��!M�n��0ᖑ�c$�I�2`8m3��׺%h��������u�U�b�ղh,
��4ᑻa_0N��8�*��M�ՒS����pp��M�lnH��s�t	�D��x���M�|��#8���y�R���]{e�yY��:y�`/�(����'^k��Q�A�1p�'��S��2M�Ģ� %L�����I�StX�ql3�����G�����Qa,P�#y��1lydI˸TJ�z���Z��6���q�+�A䩤"��'���'DQP�$�#��착�'��lZ���� }uv�uF���;������uUt2=a=7���f?v��E{�$L��f�U�S��h�V���������Qyb�L��L�5ʗo2)H��~����i�;?�μ��ۋM]�\;�.8�Nh�MX���I�ug9J���7�kW�+E޴�����h���%.00��.��p\082���,0�P�Xi���V��#$)�ɗ���,�׶qx�]3�t�#���=g�\�����:Կ�GΦ�.8��_݋tw�"�&�_�܉ٜ�B�4���N�R�>�Kg"����@ECԕ���+�ц������,O�T����=����m����g�kΡO��b�ܬ�w��Y��c�
[/�����{W�'�Q�����&L���w��`#q��q��Ih9�Vx�V+�zW���u�J�T�-���Qb�T0���-h;4��L��d�}����y~1+E�e����2�T���	�S3���a16�%.l����ɇ/�����Z���0��"�ä�?��8{{���r�CWo��2���N�����%>ֵ`�cпk�j���vK �W
��'rM��6mX(��!E [�,�h$Hr`� =�8!TQ�/p�h5C�
Jo���&C=C]�7Sh��7@�|l.{f��;��L�"Ba$ ��C+C��Ժ<�w�I�/��'���璮�A�� �<��nv��̛t�y����P	��ƙ�ݸ�E���zVQ���Ӆ�6�|���ڶ΋�1e>�����D�P�DE]E\�D��� *֨&�g�
=DOؼp�����,��uN����Ҵ��_��VD�n��[Nm�ѣ�ON�搵�,8�(�W��wi�/@��R�tTq�K߇��?�㴟��zPֻ��g�A8b;�:�hJ�LO��"8h�gޯ��vY]/0����޽HƊ������іR&I �\�� �˵�\�d�e�:�� ��Zh.��獭�a��L��,S�ș�+�W�K%I�]Q�����JAy����iބ�̙�ȓwq]/�r̥�B	��U��$ga+|�cS_���$x8�I3���3p�������l�P	s~��{�3-�sz�И��GV�Pt�<�)"�%�����L�Y��Q�����UƉ�(��!Pd)��(��;��y`n�sC�_���r�¨v(�[k��G'of�|Z�:H��p�=qI�"����R05U��"�c{{FC��u�2��jA�TO�Iޔ��b/��aG�Đ{Y����c�=T�h�"����\�8�}�hx6&N��r�Z��ζ�$�w�F�6y�Z�G�O�x����ꩇ��,:�gk��\�u������U�,��z���\z�c�n�Y�wQ��#��Y�B���U����εC��J�Tn/
�����3�|�N�y�m?�*�R�L*�@�p�¯uKӕN�KC�pi��NcK#�xjNЃ������g����l�8R�Y�&]$���B����7�^���^���e�!�YVX��u�|>�2�^���8���E]mkM2�in�q�V8�(nuF��s��2�Re��4�/�C�b?��y�f����k��0������%c�Ld��4-�0�K�2����0�%啑��5�ITd�s���տ�ϯ����(!K��2AE��l�&�/Q�����0��M�şx� �&��y'+dq0r4;��4`���٢�N`y�X�n������uZ븴�Ui�l�)�<����^�NP�e�R|#��i�enK��oKmy".�_�g��N�Y��k��,-����s-�h��_!h�g-�hh�r�6x�ba�TDPԶ;�z�+�̋�d�\���^n�:��"$*2=�    c#0���*]k�����lDA)���L�!6���)�Pؠ����]&��9���,J*M�Zsq�_�d)��Q	�ٖ�"������!��PD2��:C���A!s���yt��SiZ�{�\a���	�Z�!+�� ��~�d�W�_i��|�H����}(�����#@��e����<���T�5��R��I;c�M~"�dꇈz�:�ī"f?�96��&���sEڦ��g��Ϟ�6br��c�D%�lv'�K��i�3�;�7�Ր?F&�=�����Xr�NS��_��J�֖z~8��h�|e	R��1	La�(�
��=����]9�sZ)��?�R�vK� �2�k��Fկ�����W�nm�8�;Z�ɺ:���*d�

��~#���-ʷ-���H: � Bˌ��C��p�6$�{x@	��P��^P���C���Gt$�?�QDb�w�u(����1]����O���o�f�D-��'��(�ڧ�7LlܣW+��'FL{v#ŗ=����1͇�u�9En�~�L�����c(�2�Nī
Mv�,(�l��x�d�$��s跈
W?nw��~%#RR Bƌ��|J�����R�+���)�,�6�^��*W�꺩<�.M%�Y"�#�������p05��	����2�v�Uc �Ozf1-�=
rh2����-`�6$�P6O�?�,�ܻ=d��x��0�LG�|2���`��L�5Z���:��W��C��PoQ��	Vk���2BqK&�}�a��b�ȧ�gq��� �8�� tW�'T
�d=�]	'qй`���9��b�����y&tw���ϮsN�� ���^�o8�	����/=� �����ZϐO����{�)��w���{6ncD��S�B�ի������wo��5�J��/����j��f�=�����V��,f^N�S�B��,���]JGQ%6E��!(��8��H
Rf���Ŋ��{��L�n/�7>� 5���`�PYh�n'q��0�g�tg����2�qC*�n��z��vy�:tB�ûyR%
�I~����FX��g�H��A�l���F�$I��И$ 9��e���#]Ab� ���i�~�̬e
1ΠA1��	�9�Fr�p;�϶Ԏ�7�����|'g:K�<]���J˶I�/�L��!���"�~Q?'�yy��C�����.��gSB���Q�$$���� jy�*G�$��y���R�_ ���:[�A��M�A�×�֚b����6Yxgֶ06y�ʡ˒���ɔ��4��c^A��27f��y�AV���i� h>�4��%�(��gx��G[��Y<Y���H�ԯԼBeiZgbT�rLb��feY2�9�Nl4�di��E��6�(��@�Rϡd �,�x4�fa�b�f�*�|�T5��&��Y】��Pb�B��r0ב'���	a����K�ԯ��f*�[v�2p��xeɻ.��5�JA��F� ���������.T}͢e���J�YQv�~�Kf���+I�,R݆~v����@��ꄻ�,B�k�1R��J��5s��vê�MLb0��Ezu�=MBK�i{�^���Z_�:�#���_��^��[no�>e_W8���Z����zm�}-�_�V��| f�z'�ъiX|Q�~�;[���U�?c��ɤ��:y�b��-n��j��&F�D�'�4	�}�Q����j�LY��I��T��>V/�ʼR�W��mYKk��! Qќ薄����Q���XHzrB!b-Ү��.�Ua�z#��K�.W�WK�&��8�:�c,�V�'(Ԡ��B��|�����-��:1F�E/�Ǫ�N��������
Y�S��CU@h�2f�r5ە%�q�RЮW���,d*}y����V���) /Ҽ����X0r�H@�����������&��+¬�`�4]���:W�fA�|�y��R ��lo�J�E	�͸���LR� ����/ ]�Y�
k�����{�v���X�;�%o =��j^n���C}^��f��>GcJ���Hb��a�v�����������e�dk6O��!v6����.	_��Yy�?�%��'Ja��c�c��\r7�m��y�#y��*�v��t��*4:)����X���������K�ctܞ7�P��^���tA]f\�y��rpݏ���4  ��=�-P-B�ʐ'Z��,�Ś�!}�W�b�������1�gk���Uq�8#���֩P]p:<F�;�v�ʺ�7G����!����(f���'��<_)�G塢W"�r�pE�.���ߧ��B�Zg�5�a�8�S$^�·ݸ�\p}�4�N�N23}+�z��X��M&Y��`�+|��	D�*��!<޳ej�6k�r�����F�X����/��H�!Ȍ�Oj`o��j3��yBH��+�(�M�k���!�*|k~�<n��<m��T
8^�8���!lOdl�Jl/�i7��SNf�D�h�+өoy��☥�k��e�`�B��ʞ�9��	ڗ7�Y܇�,�wi);ח��dYc^��ٝ���m�����#ی;|�	8F�,bWE�d�*l�m��-h�,u4T�I�~�����.[pSU�K�����侅�)��¥�3�}$Y����pdoW��˛Z��T���i�X���TȔ���#��C�jUá�@��,FE
?�u���.-�Kg����G�u6ob��y|�׊�PiY�e�	ɏ���}mO�pάx��`�|Ǣ��'a��먟Kx��<��._�Z�
mS�`I�lV�rr��Rh,l�E` ��00 ���a��><W�3Q Z��z{����4Y�Bxf����4-�J���^���i��_	V'��0Á�#�ȃ��Ҿ��㩽@p������jO�c����S�z4�s�^�fOc�2��J[}��Ђ�[�S� �I�S�s�8aC� ��7��������cO%��E����&�N���Dd�<�pF&d�σ����m�Oa-�=�����0�Dm������y Njd��: ��7�-#)ۧ�S��_ p��#b�Y��U��\�F2�hN�ē���YJ���Bݔ�� X2?�,��9揣tû�
���!�p�������S�2~�e�˕:�*e���?m�V2���o�'(K���c�͖�8�l�����Z�#I�O�"O�]�6�K�@������Z{�GU�J�v-��q����{Zg0�;L�q�@� 
i�dpE3�ϗ�a�vVd�[��~v�B�a�6AP�daˈ�0�cDz�)�@�l�����װ��Q��@��/���A#锺�Q"�TB�T~gJׁ�ǟ�ٕ�y3��߿�JE8�1�i��w:����2D.��	Lr$����{��8R,9������zo�gT���灆�N�3��k=?�L��V+��l��_i������D������x������6=9�D�d�[3�������v�u+A�=�GU7^�6I�[�Ȳ�ȊaElK���u�<��A���8{�ԍl��#B���h�BU��F-3��1W{�#TiV��U�K�W��MT��r:�6 i��<���5�q��V�)�C4j]�5�Fˤ)�o����YZ��+!�q}	p
+��L�����.���,�bҕ�x}e�)n�u�FoՒ��������s�N��vĽ`&}M*�j�`eQFa�c���7:s����W�hz{����o p���({���8���#���)��f�D(ۮ�M^�d*�1��b�x}�I1)�i	3��~5sz��l���J���~!�� ���<���<�y�f�bѐ�Z�Ņf	��P>��YՂ!*�[�e�ǧH���P/�=HE���+����,��Bw[t[S�i{nv�A��~ �Ђ�)�Y�7�v��eg7Z}�4I��]	1r�[}ګS��LQ��{�1SK{�>�O�e��=tΜ��̪�Y �5LǦ\q�*�'�����d�q�o��z�/�ޝٔ}u{��2X���ݚ���o@�Te�ndM2��2+s����    �n}f�R�l����"j�})�˚<.VpMmRќ��8���2�9����g��v3 � ��g�$��Y��Iq��V���
`���dUY'I��23��=lw�����H��*����#�y1i��{!
�����u�����@�E}qa snt}g��^�.�P2���#)�:���3|�������L���_q�c��_�aO��`��a���f�A3Svf��WN2��1��d���^�s({���9��3 ���/W}�Щ�xe�#�R���\�M���ntKh�z̛�-�BrMb�&L0���2q�F�����K��0��3�i,�p�h�#Qu�<�T��f����2��HLntPj�rX�*��TV��ϣ�CO]6�Q�5癌��xPI�X
�	N��By��0��6Z�z���i6Mm̊��Ź�q6��K��?�z2�Y��.�M�m]g+RvV*�zpom}�����<������aͺ�IV��E|�ݲ����12�1���*z�S,�ʄ�ל.h���eA�p4BS��Y��di��j�ѷeu}G��|&��:�?����g!PR�D�e��:��$�ej�y���z��ʉ%�H��C�C��Vo�P��"��{��8���Qǂ�x�� �@���@��Vr���Id��j'
��v�ݾg��JEx~$U?���Uҧ�Y�_Mp�Pu��K�
���=�<{i���Q?�����}_m�<��V�q�l�,��³��� ��\ �����EQ����dH����=��&M"�O �ຆ3=<��r�x�ۀB�Zg6��߹�z�P1a;�������v�����dM�\�i�g1����W����r�yJ6�"��'+6�N�Y�/8���oUe%7c�b���^w��&�hyj�p�|��4WV��*�ٗ�^�E�6�7B�ѫ˛u��l�Fu�H�4����;�!E�pӊ��ḹ� ��//�X�΃Sĕ�n��ʫ�O�G�3)e�"�r]L�8=]z��m�İ`/Rn�����kԣU����p ~h	//��47jÜ�uS6+NUj��6�p���"������l�(rd;
��7�S�m���'�"�M�׭��<�����A�j��Y�OA�����b�@����N<4m_O��y�*1��X�]a{��cgl�RZGb|6��WL�A
˸W���E6��Ha���a3�t�G��v�#f��Z�bۻ�%����H��	��ބg�8!:m�Q�E��\p��HJ�G[S\��ܶ�K��
 ZA�2�  ��Yq�sc���I���O(gu��n����k&4�Ŷ�(³؂��"��Z�EY��m���O�+��;����jp*�N2ÎQ����W>�V�-�%�R\]������-��f)�Ej�p�R���B�,��y��|Rd�Lԇ��ᙿ���^��|� mai��U��۬���o���.��_g���X4�NZC��
�[�8a˺P��խ&�"O�2?el2�dy���j%X��.|���;E����_��q���G�Z!�Y&��D��ދj�0F]����C۞�F�����
}�4x}��载4< �v���ձm�����6��3
-1��<~>�~9jʤ��[]�U=���4ʴ,*=PU������6U~��1T���	^S���Kg�e�J��B·��.��t,�d{
�?���E�d\T3�\��O������_��GJh�E�F'G�ѿ�������iT�����{ӧ}�뭽b�x8�S6�15Q�[�OL8�:4��#��`4é���U��|8m��O�,-��z����ef�*9fu��/��~ԇ���F	�'�M���rtC��Oz?O"�F���Ļ�Lߪ�TѦ6�_Ecl�FGb����v�|�>Y�ζ<��ꨭ�()-EeK�eqr�EE7����y^��$�q��2l�&o7��G�@E����6�o���-�yLߎ,�>�NYn��b�r��gsU���.`�-��ΔT�����?À
1$����|rJ؍2s�2�\��*6��!|�$_�������=JO����\� -Rm4�uJ��@̽$��:�X���׼�		�_�ΐ��N�B��fBc�%��0���R>"�{��~�O`���U���̸�#mK��lq�sc̭b�����g�W�$L�~n����%�o���t��(�|�E��aO�0glq���"v��]|����fE�c�xI�&��UF��haѬ�P��Q�#���v{W���?�2l��~�[����0]ѢUy��34���K�����������gs'r���ӌ��_��UXw��u��զV0�ɣ������z�ߠ�D���?ezę�39<�"B��Kn�_W�<[�bS�*lQÒ��IŁw��3	�������(�pB:�UC��F_�2��fE�l�_iXF�^D�^��9�sYx�|Q-�WV������"^I*Z��X1�eэׯr*HG˨�T�;�����t����/I~)&��`�G��*���[�`װ�bE��<3x�bE�@�`�
�������}��tE��몂x������%��y(�O����Tew}�V[tʛ���kjN�'�@�)�g�ٳM���{^�����q�4D��2s�ut*"�67v�x��Ǚ2�!2?]:������?�)�����!5Ö��u꬝�Z]�!w'mֶ�5��J/RuP`���4�����^l[`7*�����n�F��xq���Unw�����(-Q�\���i{����8���3�f���8��"�yMPqyr6�D��]�4>�
Ԁɳ�ù�x��_�ܔY~����o�z}UQ�:L���' mT|�D����n<�:�k�̇��#o��v*�붇���m��͂\�ah��̊\�|y���(׫c����6�~�"����7�`6��&no0\�|�<xe��孞���V()Te](�)7�J	=9�Z��k�#p�������w�m`stt��������ͥ���h,,�j��V��U����q���L����]�����٠��i���gԋ`U&����URu+4ߪ�&h}�
Ǩ��vy��ڡT����}Öc������� �D#;��Tt�{��/�ZW������*-�`[�)�,/#�g;$�%^�*P�ь�Wx����F�A�*\��a�����:l@Ց턉&$��`��3Ԛ��9O$?)�����=��2�vvI�K)$2;9��\�����?�c����\�<7;{��RU	͜�O?ч��L����@�_�����{ʎӯ\�B��~C��4 z2��Q�E뒺sz��䀞aa�K���
u��B@���M�-�&O�燯��88%;�᳭V���U���¯���� �4a�od{��0'g�!>��nں����Lw,*���'q=��$t�D���	q��丽��xf���H-s6?#���s�Dm�Y�/���e<{e�'�h�F����w���Hɺɐ����W��MK�T\�q`�I�!����9-�ޫ�����s�/�g�7�Lq��o�>�;9�o�kӎ��Ɔ���Cb���3��퟽,E�m�+��F���\�WX�Չq��>߈#!�c�ͽ��E��9��%.j3T�4�ʉ�/B*Z��� ���L̈n3�c��gZ'6=ɀ�H�/�7���0g����i�y!煞M*E��:.�2dUZ7 \�St͊�G��I,��H#8����N(v��B�(PY��~���sʦY����X��,�,6���}�EW��~��j��N�͂"d���*�v�eܜ^NgJ%{������r$Ĥ�s�\�݆fP'^m�j�F���_�Q��+�h�߰/����˒�/�������� L�ƭJ�:1I�GE��E[^*|C����Q ��	���d?5�O�s@T=���=�S�QM�i+�kS����`s����fPu �Y�1�>X����N����,�k]��F��M�
�AЖ�΅�lu��Ed?PDl�CczI� $������?���RL��ey~����qK���}�����[Tx�*ֈY��U �܋xA�q����" 8)W�    B���4IR�7�«�lLVT6��jM�Ε����rzS�+I���RM�G��m�/<��]9y�|D:�r���/\'���Q�����QUm�FնγJ�a뢌�.L�n���G4�4WfQ7@��������� �����E����ׁe�ﺣ(�ISؙՕ
Ȓ�Hk��u��
1l:���o��ا�Bm�us;��T]��@���C�O��h�o��QP�W�|��z�N����(���!HT��m��p���4�V2Z��U��Q�D���?gO�q��|�(.���)�Q,0��`��X�������C�����������w����7�(�>�}7Y�5�'kH-�B���m�nv2��U�MP{Sԑ�C���������[�a�_x9��m링�#]L���eaL��j����]���$3R-���4s��왫h��a�o�o����\���^0,�`�~$������4�����9��=�x�����h���Oj�:�WYK��5�g_X�Z���F&;�9&�-�7!8#��D��D���~��A��;4*q��{��/^c����u#���=��E�OĚO�Y}�v�7}ϓ�ò������G��g�8��������o���f���������m�m�&Mo�M��*V��,0_&�[u��jW<��u����P��ۥ�~�ܺ,*����ll�d�&)��4�I�B*� ���8v|����f�P�"�ⶽ���ݑ��hd�d*�rh��o ��wm�潐J�&Y���bP\�~lx�N�����>QI5?A�>(��k�W�^��q�B�|88�Y[��u�/��(ć���9;﷜��;�|²�3�'�����W�����t�'�yQg����DI(��M�}/*z�����/���xl~��;����{�~~�U���|���p`L�(��&/W�SU]k�`��W(DI�f��xE������a�H���@KT��丈��L�B��[G�5�?4�UU����
����-*0���^c�e��bK�{1a���$�z�_��������[���E�qL7���]6<Zm���<��nUS��p�_v�
���4eN$���Ί������ǥy�3\�*`Yvy�B��$I���U��:k�[C�hb+�/�>?)�CtGŘ��g��:[qx��/M����KR�1?n�7�=��NZ� D�xaq��9�=Q�Ӿ���������i,��l��_����A��4Z��	u[�|�v�<e��G
b}��k9_{����\}�QK��Y��y��zu߰�:]�����~�`��Qػb��O0"d�2�@Q�b�CR�����}/o��N2�{�������.����@�I���K`��j�=�I^��,�ډd��Ԕ���Ht��/i��gRf�NJ]D�`T����
Q����c�kbJs���:/�f���oJ�*rȘ��&^(�mS�����6
>vãbb�A���h��V�s6e۶oE��X���Z��B]�ͨ�+܆R��,�^�3%�
��.�$���El��*�X���j�"In�fg�ܬH�Y��䯂���{%u��]�Q� �#k�e��w�j��%·���T�W7�0%�r�]��#GY׷V�P���̌��&F�p���l�/�:����#u��j��r�*Tȣ�݀�`�1]�Fo��\�� @8��JH!�Ƀ���N7R3z�����0��	�Z*��~tn"�w�=�Qr���u��U+g���8
�킿I
A(�T�Y��&��V��*M�j����J�w�u��b{�&X��n~�>���YW�8?$Ҹ�1�؛���؍+��1Y%(�*��䄂�B]tAq%�^���l�o�J��Cp�mn�OU�}խ(ilӦ�U�v:-g�V�v�:�o�Z�n��\�\�9��$�e��T�,�E�9~�v�l�@��"j����F�Q�j�WE�D-��C2BֳB����'ذ����$��T���� W���R�:�[�%�:����j��W8�檈��!�~\�8`�ӜP�.�ŭ��l��m��*�]���Gqn
f�B��=�|�2�,�>жY���b�XzΪ�E)ʝa�$����.��y��4��|9+`CR���[���٭�m�fE�j�������l�C�D�O���;���H��kBW����"Zu��*��I���-�9Z�Q�H��~�xK���'�$����+2'�: M�;��"�K^�A3���J�9Lb�g�����Ё��x������B@�	hC��n��dkˡ�oB)���t�e�r@6R�����G//���8e�=�I>�'4�`B&����k׼�̫����B-���z�	����cq��R��x�����v�6;�:�~�]�ۓ��C��7 �:;����\��w�Gc�gq�%UVߪ�C��u_�$ך�NAg;��5p@�v�r��A�w5�2]���A�A nː��|aM+4�e7���?��a�
t�]����nc�k����	���n{��)FwC�D'Q�F���(��P�b{�@Z�������d���ۤ�0���q�TdA	����������X�N����ﴛ�8����d���/�M�����*&�)̭��<����$�JU����3�AW�t��FFv,�$Qڌ�D����<�џ�-M��V7��t���5ɒJ�?�k~I\��ND���d��Bm^ �K�o�e�{z�πX�A�Ħ%�x1�%��ֆ�����`�)�L�)�����VRħ���)��&�s�Y �#�ʾUG �y��G�����s�L{�D�%r�� �0�@Upԇo�!I��p8TA�)I�U���<z��>�;ТB�u=�_t��7�}G���3���͎�����t��KwF���g�q��jKUӞ�9���ψ�,�19U;��M/����?�>�"�U^׷z��.Y�4LL�Mm]Dbu�U��:��l�Ǘ����ᒬr��@^��Uz�f&M��ي�'/�\�۶ ���KD�QRW�KǙѝ���0�M*��҈��*���U���ͫ[Ӥ0��}�Ut�Dʳ��8q���i�f��j_�6�ZH�WZ*R.�(B���f��_���1�����m:�	�=:�m�@�l������� lp����3e�{��Q,~c�����[G�&�ç
��D��O����(b�tGT����y'Z-�����3JD�" .c7�k�������L��Y���t��a��<�J׀cEX���Ļ�q��Uz�~&6���SfY&�-����._(� a>��o9/^�L����	Lߧ��󪤲�p��x���Cs���|��XgR�a�s�& ���_X�T�#W7��i=��I�ZpeI��l^<}l��-<=l� ��ޣ��.'������؃E�������d���Y��MM�4����"S&�����Rī��hw�M"%� �'�x/"�eIDr_w�/Ğ�fD���$"ER6+"b� �&� W���S���<�|��8(�����7Q�? F�le�g�Q��Dnj?������4�	w�:{��0�3��G4Ř�D_���UV�YBe�n�
0���;�/��G*��a�8�u��T\f!1�w#Ugيu�)���ˣ_�{NP�
.S�,�����w���'�#~\��/2A���_Z��ʏ�����o����׭���v��!m�l�cʢ1�"r�[7A��ؽ"�.K�x@)�:�.�eI$ ]U��*����2�T�TStV�R wQ�q��2�tX�v��q��`F�;e��ZQ�}�'�o��/S�,�)��wB=R#=�R��B�l�����S��˟zOۥ��o���Ȇrh��k�1��r�/ܭ��K:���F@��=�QӀ�M?�O¤�V��u*��1L˱sQ���ן�<�K�%q�=WU�g�c�k�Ϟ�;GQ�>F"�n�
s_8Z[�����сF�rS`�����l��uX~��	��z"rOs7�b;kNM]�	T���Lzi�)�_����ݓ��"��    д��"nɻU	�ytPyT~�n������t�m������� 	�;7���	��X�jC�tJJ�������Y�)/X���>NCw�q�������M5�)��$+�Ryb�-9�h���*�|�Pq���%�����`Pw���E��8O�El� ��`��!^�2�$��dl���'TxO��>���d�5�#0z[ƨH�	٭�;Oi]�+b���NF����p�%c��{/�0�խ3U���ȐR-2}�����,q��0�p�Jq(jE:��������x��;7��{�|�������S���3:�h����(4�G�B�H���U���#w���E�	�B0z�Q�"�mkJ�CܺM�b��`�(j�l��_�f��\�iqē�_�V����WH����=��0���������y�>�C<�aN������7+k��$&� �:�Tf��)��E���HV��lL]������:�L_���u���$ y�AAP�>+ld�Ó궾���$��.�yzE*`5S�E�j1�2�2���`^�BbH��<?������'c�,p��Q���&���5�"��=���B��(���+ya�-�/IIh���.���\9�-V�(z���)��Q&7�Du�~8u�mk_j<ϰ��}�,y_l���	y��x$�Fl@�	��&{���0�T��r�����꨸�8=�fR@�i�a7�/e����W��ЍBA�jK�� X���4@�
���M��gb�#�{�>�fF&92����ӧN��H>}?� ���R��CYduR����X�A���.�qš,�,�ꦊTM���7���bR$Ao�=R3q�AX?y6��-Nc���a22�Y2�q�6Ƙ	Jܲ�ՌS��i���[t��,�l��"k `���>�¼um��+�U���lG��3�i��_@\d���st��������o-���R;�dX,�*�y_���p��K�5I��M�Dw��#��3�����m2�)X�|#J����:���T$�TjY��2q��m��(Ä�/����t^WFʗ4�(:y�s����n�8�������ER���&���y��2����M��yކn\Q�q���P�dM�2,eRV�)|Dl�e9���!�<VE��b+lo���H�?f��<�����Vlb�bK��4`�e�R]����b�^�#�^��Gygu�,�q��5Fz�1y&���Xi>�$�W#iRǒMr�|PP�3����4k� RN����b���O�1��Iv��e9�	ޘ�+�oZ!ɦEt�JZU���@ڪ"���8	Ҩx�L�K�A������:�4���Pf"�&��nT��1�g�_��Ɖ��@�w#��{ �`;�c1	8��۵�[@����N���A�3KL���$65d����N��w:C�H���K�o�ۇ��6�UgV"�JT��w�zq�9{8��kӉ��@��c�<������`{�1���*���*�]Fo�ҫw���#.� :ؔ�ZYRA d����hWds���VѝL����HԱ�tr���&6�E���� �Q(��w��)�O�^D  Zdōvo�����iala(�:�%�d��f����挣�"^m�bl*B��D����Q���RmP�8������,�}��фI;y���(�8�y��x�I��n/���B��>`����v�\��Ԋ��$+��E�ja�P�V��?�_�ì��d��y�=\���.�*oR΅2��:c�w��[���}d�=��@��	�6I� ����犣���G-�>�]Cw�ls���lqxy}|��R�
[�!�|K�J��I�0�D_�?D��k�M�ڪ&���P��:ب�����jt�)����'?���uR��
�p¶Qt�"v��F�<<-�X	���K��^�� K�5��V�l�;1�lw@�M�Z$M̦����1���[��-��`����e^�����xXl��IH�",4.ܓX�]u��.��9M�/�:UK�B��lZ�g���7��߳ZD��^1.��ن=��.�k��tX�2�}�E$�����&��'=���ԅ8�{\��zEy=��^чd���-�ɖ,�i��$�2/ }��z��OQ�o0�&�����O|I��d�յ�"���AQc"�a�w5"s��._�S��z�(�>�)����G��a���9}���%�[��,<��P�ͩx��Y�*NJ�����=�Ǻ
�6n��uUƂ0�M�]w��r�2�/�=qOb �O�/P�(�4�g�x�P?�O T'�̩#AB@��N�?�]��u���G���A�a:d�J�ԕ�潨�y�Q�"6g�JH�`,��a&E�}��f�Z��0�#Z�����gr��ZBA����|���̍��-�.q�(�x��Tﰖ���鮲F��@aczMpN�l��_Q�M悐�<����xw]f':�cҬx�LdX�2��ʸ�Y"�OPU?�����`Ž���$ĦA&� ��F��/<�xY����<�u	���;\�鳼���T"�2�U�M1��d��;�?��پ�2� ���E쵡֮�/��Þ2�3!]�����w �.���k(������U����:zϞTT��mحo~RG
�A����O�zy�VT,�ԁߟE��MMYFD�~�{��E�!��
WQ���]�ˤ�Dq����:�E;6g�B,���Kh��l�'<� C����#i��;�*Z�r��+[R�n'� ��LM}}�^�E"�D��;.R�N�Y�s�H�z_�&56����q�4��+62ef
ћ7)D&`$a��m�O3F�ɞ���kBA1�tQ%�=;u�!�#��
ٹ'�֭�ʴ��]e��,��7qZ�(z֐(�`���ة�Nfi�b�r�n�I�n����i� ~��\D���%<�#��jbծ"Ob"��uЉ����vG� jO����m>���a�H�:]B�ʹ���)_���$9a<�'OV`d�2AӜu�W?�������Ǫ�Ԙ ':��z�kj2���,z}����2��c�йk��e`�Z�嫉M?��_�yR�t�@᫹83.+��H먷�{L���Gˍ��=�JRU�t�`/���XY{)����?�q�y꓃�B4�i����=l�f�Nr�<"15׽��X,\  �S�2ر��_b�k��G8��T��7B�XH9�w7[��B�h�<��U�@ �k5nk�+�Z�Q�S�������|��z����sa���Z��ó��-Nj�	,�7qQ�ي�H��l��}#9W3�Bs�9o2e��#X�D�"_�_r�o(���W$&�Q	�x4P#���w���I��5���ʲ�	u6.�Ī|Ҡ�a\��,�a!���E+y�[#$@a��|�2I�8=
X%�e�B%���,������fEq[�'F����ͨ�!�A��������^i�I~��P���8�u��r����I����Z`x�§t�22�2����$�Z�G�Y�i���3qW�+v2U��R��6b�D"���D���=t1ĳ�c=�i�3߮ƒ�F(Xb��z�rr�$����8�t9
�ء6�JmR��N�$�E:�̃����a뽱i�0�i��`�*MTm1O���鵚T~�}���&ðW�ʋs]-�0�::�j�RR�u
�=]z[G��Ze��$0�6أ�$I�B����X{y�utxa�Q�RH+2�~��՞�z�4*�+X����:�z���t:(㲁"|��5L-0Qu�~\�N:n��§�������EٺoU�BX��T���������R�ӛ䆧(��� ^��6E� �&�p���o��
&�� ��3�v�S��ϤS}D1���N�`I1U2���� ���v2�~K�舼R�/Ni�:,�6\Il]1����F��,���_��`B;T�:S�^No������U�_��4x�c����{�	�X6��������}�oL�BY8{�t�������>�ĵ�qrG ��S=���{���pOe�u+�U!byN��aB�i&!aY\���!��F�    w�ut������i�����1?�9����
�4���̊��=�꼈�{8�- ǳq�R?�Un�tV��4�[���<fe���m¹MR�}�>f���2z?27�qj�f!1 .�^���]i�9	�ı��A��"	������o�bE��L���*�,�q� �Q�e���I�{�'Eb��a�,Kg�w��1Sa�yX�*N��T3I�����X�y^�,ڗ鳧{E�ah���m=(ln1�I�Xsˌ_�K�a����r���)ٖr��V�y�m���Y1ή�Il�<���,b���:�_�顚,�ط����+:k'�)S�E0��м0 � ���_�W����3��O��� �>B4�h��O�YH����E��X��#���qܮ�Q�i]��Z�y��'匟��a����{�1�@�ُ�3�v��-��Uy�SlG�&��W�^]�6��{�g\�vsR��6yLk!��w%��M�菀�:+h������_[�<T�"+$ty�ݥfvO�)��{���b+���#U�O�bC�F��orC���<��Ԕ��ehjK�dE��-'�E�U�N���w/x&�Lm�� Z�����폊���h�{(*͐Lm�yP�L��n��b!�V\��Rܔ�[�@<����+�±)1�-o�$�"�m�ڪ��a�ˬԃV)�x�\��u��%&X�4h��9��8du�2(��9	B���CQ+�_e)~	O�٣�\;��Ny^�H���݋�%����S��:KiO���*�C�ePH�]��@��ʊ\�=0i8�g#v�}��!�'}G`+�8�����E�PSP������M0���Ŕ�
��l?�.�i�p�Pg�UyU�U�f�fE`�E�%qZ�fɹF?-Lm�g>�Pۄ7���z<ܺ�+���$I���ڜgQ�r43�=��x�q�ٲ��BkPy�݋X��	nZQ������6����$�<��ۓ�O�P�����\s�.�d�x>�j��3�a���
ދ�|:�_�R��+� `��fG�G��A3��:�TU����W\��&_�5m���lcG�J�4!55�S��cR\��Q�y\��(��5Щ�*�aR�֋�x�ͯ"����'�پx�Oѿy����*(�VnY�m���-����s��Wq�'�A+������ᛔ E{�l�J�gU7"�ej��;>�툲��o�_�cs5�چ,��<\��̃��jO�n�7.b�dE���I��M�&&i^��T��c��%���ˬ��'9^m��!�ܧBy���yرh(�B��Yۮ�y=2�Ƥ�J|��M;ay��?�k �|y����ɵ22��e*����_m���F���"�C�G���jϴf���9�T��s��nķk�!}�|-�q3od� �Ѱi|F���䡕��1�,7W�l\m%PH\���>�ܑ��ޭ_m>��P�^�1w�2H���8�Ȕy<Lf�11����"�,�7;�p�s�F�8p*��dD5���(�.G�2>�W���P�q��6�C����(�|Eˢ�%�U�upݕ�=�o��y���CX��Ϡ�nktBK�`9��6"P�pFR�:�<�en�����P��mb�>�UQ��}YG�4t�?7�%��~R��lf%t�����J�����4�rc[�4Y]vWKk���E%W�>^"�N���*�Z��>R��H=Cz�"Nu���6�&�Euu}N�2.8����˽'r>zO�l :����I�Ra�`pۧ�Ɋ�$E,�a�m�I��bKb���lUa�A�fBrY�6y��Q(���7s�鱿W�Re0��Db��:��i�͖���:�c%���t!���a�K�㒕�g� f̫냙e�l^+݁(H�>����&��ҦA5�d��6r�m���q��[��7���W$�{��Q8{���o.�m�8�Z��2���"T&�J��
�9fLR�/kE��X��"�L�S��|�>iD'�K�	���Vo��P����*��hX�9�F�J�Q�L�"�e�B�XB��V��湑m��_Tdtdc�b)Ř�t+ո�7����<�ޙμs "�_!�R�hCf�Z�S���%�%���y~xq#k�J;'���z�Y+\���G]�`z�*����۬Oن
^�<�|b^�'D#I5����NJ6��s߽8�{�� _J�����(u@!��m��� el�ę� �-�����(_��tt�>�E|N���ǹ��|�?��$79���V���E��m��*[�i�4�BUEo����z =�(�u& ����(���=_~мM��^����v0�&x�פ�¶R�p������.��&��,��q��XQ.TeIXW�p�S�C}�`�<)
�8�{����U�&,��k�Е�α���&��T��'��Yi���R��E�����dy���y���c�)����D�1����1	Q87�po>
O���=	�� ����VC���F��`�ݛ������'Y���<N�#ɪ���6C�l!�dy`��`+S6f�t)��\��uRxQ6YQ�o�3C��D�%~>���v =��t�)����p��?j��i�+Ұ�^钙I�q��?D�I6�3�����"}�g�ڕ�MM �4���R�`t���t�_�C�N:	b(c�8v�Z-(���U@��L+��xH�������J�n!R����"D#� ���i�3t°y�=M�r�j�T����6�糪����`�NM��8��LSN:sCU�D�<�ޒ��M���+u�vw?�G���MXw���L�$+�o�m�e�Ug�v�"��[0]�Ii��I,���"r��1�������eWa龡���钮�~�foM)B$���~��,���˸wАa�a��$��4���iopl|j�&-V��>5r+���3{T���6A��0�)8{�P�Z���D%H��a� ��i��5���xS^İ�e�cV���D�T�x:��텗�x,��l���fX�c�َ#��~�B/���\��LM��S�I�vFv~8즉�'���;��,�>/�����UQ�U�l�|�6�m���ˋ,�L������3��m�����Q�M���
��a��2��_M�<N$��O����d���S�̼�,�c����K�]�Y���~��(�� ��s1^���ۮxB�Q�?/��#���f(��M֯x�Xj�$�m���u�}?�D�+��,"SW����yQ��Ui�A	M���t��9��k�}�m���'�"NU��6�F���r�V<ĵ-��eѝCƣ`�l��\���?1*��)I?��ڶ0ak�p�&y�C�"b����D��X��F�38�rY�iɡ^������!�O�t��w�����<�	wSm+�^�9�⬒�V��;nP�]��#�E�xj�pU��<PM}2[�	�0�Y��]y�Ħ4+BV�L/m}��%%Uvt�:ZD��8
��N��D�̭<�I9��5J��(�zߜ�a�e�	E�6C�^�ي4��$���J 2��c5z��t�o��4�<ℂ�
����7�g�$,_�,��]�����P�8�i��z��9��g�N���c�Ud��ec�������@�>�C��=Q���rj>�3��=�4�Y�([=�ڲX�2qeo����P�t�d�6�N�^�W�̎D:�:O��y�"M�[��}]��Yf�41<IG�j�o��k�oŝ�"v�|)����q��������[+K���('�데,��H��R�����CY��a��j�1/��k�̘��!�>�,d�6�!O�jP��p~��p���k.��<$(0�+SͿ�|M�6�$�$���YЊd�}5@�\�����V�M�l�.8>�2nu\����, �s�,#�o����Wi��($9GN`i�Bj��i�+N��D%�&�u�[j�1#w���f�׻�H����q\��H2V    S0��"�dEU�u,�kRDw��/�$c镞!�k��%�/����֔VQa˩p��"�j�_f�4�I��������0=��=��x�Й�CI9𽏐&��wsԠRR"!T��h��I؞4�"�0�8�8~�B.��V�Q�`Y����j_I����C�����Y�Eq���HM�⡫jc4du��o#���Y��!K��q��Z!����z4� d�Z�,+ʢ�W��5KWG���:����Oq�~�
�L���OR6�v��O����ؤL�DC��%���}/�n�@{8���p�&����n�ந�(*�~0���0w�v��{�/��}��!�)�Hmn>��g�A����	X�����o���Zf�����'�lT{�v���a;4�fF��(n	��Wm��ݒ���ŝ7�X{���� ����L�Bz����}q��v����Ȁ{L1~�ϛ0)���LJFa�P`������B3�X�"��4��PU��$�n����S_�3�8C�+
f�$N`�r	̃�h�fEj�:�`�E^�iɽq�2Ul�B���]��+���;D�Ѿ�$K>��s�QH��p3�����p�m�~ �(RSH��&��H.ԠR�)~��� ���e�y������3���/�]r;��礒9��ds#-XO�|@e
^�oKu��T@��rMAe
�F�R1Szh��"�	��vs�$$�q_s*oG�)lA�2���;�F� �:�B�d=^�j��_��4���
D8	 U�Ӊ�����4s~�!Y������'�TU�/_){|L���yQ��#%3?�X����-拢!�=!\�6?�q���I� R+6`	6��v��6*�OWTE�ٔ1�Md�+b��
��;�a�JKc��fRi�N���-"�۶�6P��_&+L�l�8)d���'��*���>�W/�8�YV�,��L�d�l�y)n&IG�Of�������8!3�d-�H$�t�������`�e�^�a��=yȲ$��/��RZc���4ԁm�s�,�EL5dz<���k��VƙI�NMB9��z��ľ��n�3��dBN^ᢨ ��WL@���?m٢�Iu>�z��@P���Y���<��A0!�2��n��T�?��˨@8k������Ӌ�G���,��Y�$W�E��%��Rw	��>�+��|!T�פ^�r��\\�d[�./Z��Y`u�`�eYe+FG�۪j}���N���,��
��lv��6�dc�S=�&�Ѽ/��@��T�
��<�e�����R'E�k��1�����H����䏼�WY����)k[ȭ�Wb
��ee���|3�h�pO&�˷��$/�X�}��������m_nU�d&#k��nEq��qa�ݪ��T����6%,"�`n��3Ɣb'�Qy�?�fI�Xb'N�{���o���L��p�b;s�E��"��V�"����e>a���i��h�bBڨ|���:F��|���/'(i�E*���>�y]��	F�)����/g@��Jb�赳�r�!���N��T�2�gz�n�ت<����.���˻���Mb����0�9I��P膉q6���h���(4O�O�\��qnb�}����Ma)h>�|�_t޺�-�(��t+j��Wi�7<���^a��QtA�6�	&��?P�E &������Zm�c���/�i���n�m�M�&�ش����d���/=�e��^[~�Ɲ�f��sYZZk��s�Ύa�//m���`��*��lE�S��f�,�{n�!&�\�`oM>�?����5�2FuS���UI6�kbTƙ)�~kĢY�#�orBҸ�L+�1�P��R��ɂ �s�ܑG�2r��[����U}���HfE>.3{�$�E$�6j~�U<��ty�D\X4$�'N���	V�/�J��؞ɀ��"��-
Ӱ8�`oa�oae�B%�,#�Q|o�!2�c(a�%��YJ��Y�}E�9�1���wh��������張��2�u�&a�`����Iҭ�/t�%��\�Օ2r�n�o#��P�?
k�=���j�W��4+*{��Dg����掝���2�?ҝ��:�8�H�m�/<͓�� ��~߿�T�;�.$z��j�)�rD�*�+�}�״ S(̬�Fl�fr�J�k!�wG�yZ��-�"������C8A�ݶb\���g��ݖh�������X�����8��w|_T4������`{7���,&+��#��/���J��5P5��:���i	�A���ZjR_]cg��3��0�<aQ!,��'�f���j�*���~(]Ķk�In�F�r&��64 �zWb�s�>^Q�F~ �I���L�_�ٹj^�X=��?�>qǁW0���j���t�%�,$um;KI��G����m��<�G��v���vx?�mL�B��H#�I�F�D B�!s�?@q�[�	�	��h>�U����Q��lg�:�FDB���(^J�-B�ڒ/�D-βjǬ�>~<���SQ��|�X�BԻ��2�@R8��/��v�.��"05 i>��W՗�
�wa�\�e��&���R�^Qy�LL���:�$�M���<�zph�l��|���ܨ~5��
��"/E�*�e�g*�c��Mq�m�muxg��	m��#�qG; � ��X7@݊
~ lQ�$)>ɇ����E��oZ�u�W���Hx��+(ݪѨ�=�d'M�-��Mf��0���[2�ɘ6�/���ݓXF?��v����>��F�P�����8o�(|Z@�"�Q�:+��6xø�ZEw̟d��!�|���~׈6��q�[�Gس6��f�v�bǻS=>��y������0���p�wm�:]��1G��;�<6U�]3�G�^�uAf�0,��+��\?�(�B�YEݡSF*@�F�p�xy�=:�������J��
�K��	�^ǖ>�r	昢-����Oh#i<�D�6�����=Q����6�pL�?;, Ut�B9�b1�����ȱw3���0�.��	R0B���v�}b��삝&�o�����Ͱ��Hҭ>Óm̰����.<���*���<�ڿ������F��/����
m�M�k����Y�&�tȾ.��.�8�~bn��*��dAh�-/�U���:�ED�eq`:o(O��.�si{R�SL�4��=�bV�
����P'��P �Ꮱ��0/*�Z>:I����P��ef*]BY����b�#pR�E�Ȳ��P!���v���+��$u������=n��<Gv�-�%w����R��ﺂnIuY���E��[a�}�FƖ�U*��"��2��j`��!Nh�縛�R�d_�txFSt'�0Yx�IdS�k7�C6U�\����bi_�,�c�Ƶ��
%ᲈ�)���>s�m�ʎ��Y�!/�*�qS8Y�&��<^�*W�r=��G���Q�V<Z'��_mފ��=�{g�p=������7�y�$yS������zA�����q���>^��E�\<��P[��w��-�U'M]62y�����=�4�8���T���C�T�rp"BX1�4ɏX�b(Jm�����:s?�w��л�	��YТ��C�^!�'�󂋬E;͵��-��G���"C��:��H]�9�#?ޤE?����?�9���.�!g�M��"��&�����g�y4;���x�zd�'�MZ7+� e�g�](��m5��˴�����,�y�x.�C�Ξ���T	~�?:��I�2�P0RQ��
�L	��,��]��oh�iO�w6uDr��NȨP�1��{b��]����ʽ81*]�9p�������������_�o�{���TW�h���Avt޸����߀S���7=(N��N�p�x��Dm��
N6|f�{��dE�4�q޼b� @�Lyg���٩�۞�D�X�a�	2�z�9���!֋i+��&�,��<]�.Qŉ㒔	���e�}�;�b<���*;>�ı2'�X�C,9�8�a�`��(�����Jb��J������j/B�`Q!'u~3t    ��j�ߨUCh���N�rq�v:qz
Ɯ�l� ���ꆒ�bku|D,����D����@fBG���Ga�����HE	�D�/�;/u�㋤j5�ǳ��`LU�Q��d�8�G�O%��H�_�_Q�����
��è�a���of�F�߸="���?N�O�N|UFY��:���:�-ٚ��V`����RP�Y$�=j��|'S�7;�lNy��=���:��{"K`��,[4�]5U߬��T��Մm��J��Y,jb1g3	'A��ͧo*ۤhk�D�0z� 7�%"�m{�X�Vi�:+(�"��YwI���eI->cI�G�O�V</O$��>=7/'��EL�$���6����1+P�UV�˓�Dѯ���F�+g_.� ��eG���$�_X�p��$��|�%��/����Ó}-i���P�� �_�d�H�����G�갇��臉C�{r�'D�Mq��:���,����f��s��F(��3(K�Kh���u�Eh~�:�mJ<l%헆�Ֆ�.��e��F�隶�V�]����2�2��JM�X+q7䓡{��sR�J[C4|�B��f�v�p�9�i\��du�ߨ]�u�
5�*O+U])����D� ��xu��7ԝ��p�k�I�n�&���>�'%P��-J�E��bYA�B��x(�bE��̶��:�	��������V*d�N�^����^LJe����-���� In�Ѷq��i���\X��[�6����l%"�f�^�Jv�X��L!��L��M�n�Lne[]��V���l�p��BU )e�/"R�U�L��MƲ[��V~Q]���-z��)����U�֧��Ue��, ��ߦ}߬��j��	�����d��8�;�:����6�=�C�Ӛ���N[޼߽���S�#p�se�f�4��/�'To�X��s���������㪇��_p�E�K�{�v�8��crB���Ā��΋�ظ��L��Xe!��kF]N&2]C�i�te�~��=ZI��@`��m�k�=��w��zS	�9a!01�ߴGBu���㖑�͗�Ol���5�+<e{q��;�&�����2,5��a�֘m��͊ǯ.�
�W -3؄z�&�TڧG��xi��]L��ݬsJ��Ne��P�,��	I�͹�B��u* ��/�Ah�⍒߷��5QV��'�]���r#����_����ZI U^o:��}��P�=�׋�
��6�X�;z�T�<I��W≒�T���/��~߿�}96s$��-��yy[��%�D!�A�$��z��U�t,,��,Ol�S�&`r2cF��5��3W��:��D�u}vZꏸ��w<8ݠ{9�:v��ς�ځ��p��'x�:Na�T"rl�"L��}֭�\�ժ"�i�6)���q���y��0U��b�w���Li_9�v&�_&����� 9C���vQM�3Dc�ġ�������#�̂���$�a]��"�
V]+���4)J�U�_����ˆ!��f���ݛ��Ȥ�)Ӱ��`C������uZ����:�͉;	�C��v�K�)V�f[|��+J16�{�����C�xV&�J[8�c��k�2uVg���������JH�^~���Jl%�o����9�R�}!8����P���n�A��*Kn�սmk�GYV�_�I$��j.-�n���É���PZF�-�
�g5�DQ� ��~(4��b��yg/��i�3��m�S��^�;�9�ck�ye�Q��"N�V+~Q�~�B;�������l|m�ּ8h�33��,3�������Q��~���Ґ��Lk6�����s%��f�<�qeC4��N���-l�w��[�?�rح~��ⴚ�&P<�i��l��-V$��8�i��yiA��@���+����v���e;���?���tINǲl��"<�ױ���5z�� s����N|>�3�B�d��̼Dr�6���,�W��x�=\�;c_��C]겨�[�6�O�у������Ľ� �O� �X�.%ݍ�A+a���)��K�~�
v]�R}��"2;����ȒW����*G	;�5��1�T�G���<0*(����8�@U�u\k�Uc�� �[Q� �'U���u �'�	QJ%M���Q���r�)̀����H46��b�������E���U�M�P���Ju7��@M�u�}h�C������k!�b��Ar����E�Z�B��	�_er�A�� ��Ꮭ��ͳ8�Q8`s�V��^Iy��[7���ˌ�@��~ �F�2ȁw6�\e;�Y�N��vv���'� �����
�\�q�]8�f��m��T�Z���e����$���C��Kݨe��ax���?�t<��u������\0�9݅���eX�47*��eMs�Zw�*����V�݁"�;
��1i@\��A7<�g�Y���Ni�͢;S���TE�e}��@�������-/��1�����L�ӱ���kÒ����K��?�tO�'�?�[$�|����bH��ҰW�� 慜K��X����h��B��*�p%b��$Հq�
�iTy^�"&U��7J���l�W�$�S�?	x�['�iխܾ�b�h�;¶�m~>��c��t�Yn�����d�7�6�)��C��:�G��d.��">Y�Ϟ�U%R����T�d���������ـQ�xX�"�5jFj��A�$l97�1DbKJ��+&qZ��,����LS%)l���e@�<�������V�N�%J@��V$	
Ppp���M�vO��~��,)���W����;�^���K�+7�f4fEȪ$�G��^�0��(�9>�hn��h�X�����g�m�ږ6Ŝ�ODJy�qT<i��$�)v�v�0�뺔8���6�)�mZ�b��8���"*�I갸�p�r]_�����(�R/d5��r�?Q�&��ޑJ;�kN61� �$/���pV�K��8�W��P�w`_Ɵ���y�P�P?
e�<��v�C��Kb	�ܴ��]�W,�H�	�[���	le&˗�I��q����H���3�QVwr=`BJ�IK�	ڦ�Fh����C.܆�4S�p�4��E���(��xN�8�)\D�qFɤ#�+�a�q�����?*A���\yV��A���������4u����>x�V-_�F�UNЁ��H6����`������q�2��[H�}0BgI�"�T&�}�ĺ���&��G��$��V�䨺�� l�<�Y�~��?��t���ekS��&��M0[�>��aE���T���*m��k�K�7���~�����$W 2�C������7�
/��Č-m��N�2[HCC���^���^%q��VB?����<��@]�m7�
�,�,<Ilk��� ���A���d劢1I`�%�ɢO��o>��'ioຸ����։LKw"Nq�`B�,	�y'>���WT��֙	�M�<�I��+���*q5�o��z�$]��
�E0�e�7-ı��&���KҤ�
	F�!�J��������F\��:�eQ�غ��â�Ý�b���SZ����#�I@����m�/�ݲJ�^��l��!/!T@Lc�!,�4<(�r��G�If��*�/��h��Y��Vuv o��e M^Z
��Qj`;W�&"�n�����4&�4~N`?W��l��G�1�W$��ȴ��b_@	.*�c*G2[u|*"K��@��"`&6����[�2q�����>Q�I@������M��S�83�����)�����z�����E0)��iK��N���'3)M����ۋ;�کyPU��T�w:�'p�|D���s.�C}��;r7�]�6O�,��Y8{±������>P��ә������!�AF,�4yƌ������T!|2^��57��g�8K���m]�:�U!�'M�tfҰ'���}��I�EĠD�^olLb�|�0�?��\'��gQ�xRv������rs�\0o�X����la@����A�e�6���vȂ:��Ja�����[�	�|SK�8?�t"x�    �=
���
+no���o��}����r~�$:y��n�=��m�0��@��9�
�m���ڴ��/�Q�>��������m/�80r��4L.���w�	-�1��^�� eT/���3�C�>�{���P-bTd&4�#���A}��%)�8�d3����(@08.�I��e��*�Z��3|������t��&����-#Z�\��d҄�x�tlW�����e�`��7������m���B
�D%W���!��a7
�\D�4������c\�+��*I5`yt'�D����dߓj#`K�����e�'˱E��85E��04������UQ�����IA:C� �x~xԞM"���M�gj�ΈF3/�G$��;V�d��<.O_������Ň�m��1u���3-�_`?��}�8�IB�.
z�~�vҨv��ن�����bB>i���!��rESW�"��U�O�Kn���b�ez=p?�C�FW�c+���&���7�^)�P`�x"�!A�cQ�&��N�%��[p��M��4�uDR��-���'��壧��gQIa�� `T2��݊�ԉq�YQ�����N���9�6BN��["�ҸJ��uY�W�dɊ�D���Ҩ$�䩓r���o���|{#CR�XhA'}��4��i"���[���B�M���(�����o���lw���>�sc�����M�^
��e�)K1��!��x!�X����w���{�0'��ږ�G�a;3M2ܾ���[];�`*�m���<V��#,��P���/�ɦ���d{K,P��L ��7'#�*��a�����Mr}>M�$��4Ki$��V�'��聝�}�U2u�ܣ/CU�uv�l5qU�+Be�9��Y�n��U�~�0:
��.�p(�񑂏�S!�E(�,�Iv*n�1c�b�lV]Jǐ��������#vUDH��z4�Mi]!B����m���k��FV�"^�f���ǅ7�;��LHz)��Zu�!�P�]U�m�����k��땕�	̽#�&�W�^�d�l����0�u��7�m��v�ִ#�d�.=�,c��ݽ~U�B_�ŕfG�2�~�*ρ�ThJ�d^d�fD�&Y/D1A)�ܭ�p�y+
J�/��8�nTqth�&]qM�H4T�k\4tt+ �[^��}m� ��	H�g�ϥ��^�dZ�`Ƒ"��'�j�%�&�����1�9���>�qp6��D��LN /���1�l��˽�O�7؁2�K\��?y�H�j΢]䨜:<���q��aR����T��Ȫ{V`��Ј�L�x�4�l5^m>���4���G��#��?g��*4�4����fs��*e�Vɫ����� ����`4��-�dśP��b���6n��Il�=c�R���q�����/�V)b}�i���V��)�#��-����pqWtݰ"����Ncb��;��HP vZ��<���W�O��L�&"�*?��4FN�*N�[����hZ�"s��r�TX�Z8� ���O�6?IJ�C�;�g�-bU�ƣ�Qo�a�|�ݭr�=�v�͠4$d1G���kV��$�TՔ���}�M,fɋx�Щ��l�>����y��$"�l����r*��ߴ9~�2y#����kڷ�-�U�E��S��2�_e�m�d�i��C!(H ���d_���|s���V&�y/q\��:$J6�d���Yv���%����h�t$�M
�x%pwQ��lz<6.\���|܁d/��g�l,L�"VU�^�"�Z��͙"�x��F���7�)I)��g�
��38٩��E@�ΩI�yX��G��-����F׿k6��:&0e	�G��8h�`l���s��P3[�u`�p~a���k�,�sw9��+-� c�Guz~>�_�gd���Hf�2�rl�@عr�W�I3<�z�蝇#��.��H�1
�ܷ�~a�m�Q���F.�Br%&��l=M��EpM��m���:��[���C{��'��B�3X�_��H;;�4Q\D+O�*0*;���=��
�]Vd�hp�yb/�^=j��C����c/�Xp��n��0<ڋ�}8�+}*��
 O�#r��zҋ^��������4����t��24jjK-sN=���]�/��̘�c5S��IP�?Zʄ=�<0�2����ۤ_;�0�~��r��c-2t��h?�Xbr
���g,5YR,�����gd�V�JpT���H��9���ĂP�D���;bAd?ËX�{��IQŷi��gc�����Dl$KL�Q�tg\ģZ���<�:@4�R쳪	{�nX��*'z�����:� ��A%Z���JFE}�s�p���X�Ū��0,�6�u��TC���8�E��n��<�,�����s��K��z	s�:�*��Df�p؞O���?y�3G�n��[<9ɪ�������E���Y���?5�ؠ�J�ٯ����_ E�g�Z�a��"}�Ġ�w0����K�3<�c¾~V�8I��w)�{$B�/T|ѡ�8Q�
�Tp��@Cz���E�w�_������-s 8
���ű��"���� ���\}�M��X�<�()�����J�'��?̽�rG�-|]o�'PԐCե$[��g�:���B�@�h �~�?��;k�}��Q���՚Hnf����O%7�θ���aP���a�/��֜{����'�Q�$������p1r��KXS����ti���7"�!��Q�R'���ԁQ�}ŵ�-~8�ZGxM��i�*;�<��;����1:�+�p�fҡ��<�ѧSK���Ȟ(S��B}X�Z)�-�z���q�\��`���p�B��ӣl����-w*�6�}s;؄�U%Ƭ�>�} ���^D̹1���:�A!n�#�S��㑛����o�;^.;���m��?�kQ:H��l
R����������)˪����L�_��ãyf���p�E��ކ$*�ln�_p̪\E�K[g����|��B�gUE#W�������u{ϩ�7���:�3�I�!t
R̣��/pnfsg�]� �MUȲ�6B-����Ȣ�|?p���
+Z�S�(�Mx?�BX�L��{�7�n�$��f�T��}�s�j(ns��^c\e��<�a�}����{v�T�[t-�����#�qi7ax�	TTɜ4��i�ĩ�%6�}�]P:Y�-K@����4�0�a��x���H>��p�z#p*�~Z5�tUf��-U����2������jE���.k���u�VI(�1j�[g�<x��fv/
:�	K��︪���'�=�:{�	�H`��3a[OC�0�IWMw��e� �e|�/g25���2>�Ob�*��݉�@����4�w�����.�����\jg3��Z���`+��m������ē�Q�������V���4�/(qX%�M��	���ٜe�1q�;�����~eϑ���s5R
m��yK��d����o�WQ&�'W!b�:�-~f�w� �?���M'�G��b�"�A:Zf��_�xB�&]_d钅��m�	�H����>a�C��%�ϱ��!R��7�����m��i�h��6u�úɻrAaR�^A�.�mWRh­��=p�pNM�'�:�[b���A�΀��{&�M��Y��dJ��&3�ۺ�Z���bA��~�Z�Fkr�G�Y��I5�8�!"2&�G� )lTf{� �:O�Ti���z�S٘��J���W�S�W��@�$ɉ3��M�фz�~��ݡ�]���3jx]r�؇�G��7�ǅ�0G�h�����ii%�Qj
�����yS.w�y�C%J>��f�Q����H{�cxƦѱ�����d7���X����-�n#qDh����h�'i���)���H��x�4^�WO�:��b���m� ^�����e�ڵ���*�@z�w�5��8�����@2PB��a��P]ݩE�_+[�p����T*5��*��>��%��%�U�k+��s��G/���"ĕ��2ն,��	;�T�n[�b��Ĩ�U��b���A6\N�����Pui� 
}(�C�&�`n܁��:X�BX��    Jx��Sܚ4!�6��[�h2�٧P���R�wȑ8Z�ՏM��)����%n�ew�n��Y��W�e����n��^k@��9�}"�K�|�)��HF������G��c���)\��h���,������^�>��u�^�8Rr��)�������΄\��`�.$ե"Ƅ广�Ps��'aN��� ��=���uq��/�E�(�(�hoN�^������`(ϐ�y����]԰���N���a)|���Y?���U�q���D�v�k�O<�(��,����)	�7z�$�P�>Dm�Q�>�N
�9=�&��L۳��5�G�^/x�B2Tj_z�w�}�E�;ؚ
6�b\�I��+%�><@Q\�hK�W�t�<���) �u�(�[[W
��MH���`�tU����8�
3�?@���G���Ź([���7��|g��HӤ�|�rٱE�7t�CUj�Q�!���`%%��vGI�os����W��S�\R�m�:o�	~U�U�����S�	�Я�	)G�OL�����-Y����~w��g��^΂�Te� ��Mk���o�m*Y1�%f�ϣ\Y+�j>��up��� �c����,\ފjzJ�x"vZHSe���˪�pU�τ��9 ���>��Cr�:4n%f���J��Ŧ�łf���*�Ԇ���G��QT���]�g+P�t�;�O{�*Z���0<�������"'�c4�6�v@�N���0T�b0��]bi�ov��<�W�Aі�h�n*�o���祊��Fk ;�Q����0>�!S�!+9
�C���*��0G�v��1��njh|�À�&�M�q�G�F��M�Z�nY��z�jR��(�1��rPR��
X�'5ĩ%|�>��?S̝:���Ub��=���Pɀ�e�����z+�ݺ�15%���>��BiY�,���ĠZ0ǽ`��6��e��P.b�ֿ�o����$6���4�g���++�h���P�}�M{"�zw��^Ե�CC`#0�g1�m�8E�E�NY}���⨲ 1+2 �Q����OTt��k+�B���<Ju�ڒf]�iv���Ã~{�*W;�E6e��x��>��2�9�k?�F|>�yǧyۯ��N�9bb�.�`��ɽTRi��.x�-4�U�6
�D��~�,��)�zэ��qxD͔�y��[A�=��{B�w!��k��1r�t|�PC�z���(d�Y	`�^#�C1|T�٢R5D�VU��o��&���[���j^ڽY�o&�s�S��e�;��Q�� �	�5"1T��&b�6!@�Kdg�$���L�D��%>�4�����_cG*h]�f}�PO�
�����_��T��DU[��s�w��j5&��
�<|\x	��b�Q��Z�����;+�<8c,���!���F��E��#+^*/B�(��=�D�@:,�k"�:�d��=YY�(�i3Hw߈ަ�1
��YPj����o#��6I�N�{�ヺ |��:K�
��������?[���rאtG\h��OU��AB´D����t�O��(��o��#��f��-V@º�8�t�c�8[T�}�*�������P��uc��^����}�������
I��ik�
�F+���
ز�������y�C��e��{J��ԯ�Y���Kϩ�<&u�wbw�T���ݸ�i�k������-�('y���G��ǳZ!a����ȕ�^�8LPf1�>�yژ%���]���$\���MM��~�����VѾG6�Thy+�Q���>��� X}券h�w3���i|�@�rәj�el|��$�M�;m�d��[du=B��D�+*nJ���I�����W��PNXM�����U�4��|�t�ER"�mY.Pp�󲰨�\��R��)٫_���E��q(�r���a�Fu5\p�Z���{��N��=���~����h���f�����,~�jwx�=��8��y{�`���v��Ch0���=§�k��(��*BF���e᭕��;��N����
�:��<���̴��]x���6�
^�����[�Z$Ⱑ���IR�i�X�Wa��fXu��~,j'b�1Ԡ')�3��[����_�6t��4�8��(m�p	5�~#8�A���@I -��i�gZM*�:O�0�O���g�A���ƫ��U��W��.��A�?-�5]��J�Y��4��Veo[f]
~��{�+)�
m�;|o�Y�Ck���)�/=��S�A�-Ҫ�m�ۉ��2��&�&���|�%}�ė�f���+I7J�n�s?�ᅔTy�BK��غ[.@5�Z��RX�G�@�i+��8ume*:b�-D]]fK���q��s��J�8QH��e�r�E��`�r�dVY[/����5��a���M��j(4AYD��H������h2�@�O�=&n���)ͅΧB�x&�������e��B�G�>�t�&��IV�y�ۣ�r}���-�i:)B��/��R&0r������_�_�6E���%��T����FK^��d?���7����ֻ:v�قzg�؊!��jl�`~�C��V�ُ��T�����8F�}g�����l[ɕF-ց|��Ph@�-J �ӡ�{Rl���sߏ�q�5�E .���th{�M&!G�G��b-���A#�J	W�z��KD0��n����.j���@����Dޚ* ���YA��6r�@�AE~�r�B_�����T���2����.�؆�:^DώĖC�ї���.9���Bͩ�"{'O����|��F�? a~`̹Z�<~wf��I,�a�.�$dٍYpW�RV�U��[�#)����x�j5��;�oDݺz!���U͗(�8a�-�*��v*bk�Y���P�eQk��r#�}�g4Q�Q�|߉�̀B��"�K-�8�`������3a�����K�<�M�,��ok�����A'���;���.*�
�\�[G5e�QwO��I�o`�u�/
,��k!o5.���,p��z\�d��E�|�E/8����9m��b��w��!�:JZ �y�X~*T���e����M���3�z�@%�.�Rg���ۤ�Y]��`�`��K~<��e�%�a��؅�K������Y�b�`�?���rD��t4E�l��Țbw�,*�#������$�|ʰ�%�I, �q7���8`���	P�P�����(R��E�Z�Q���(3�OO3��櫐~i�~U���R0&�1i��U��Q-�fǳ���)!-�T�Mi�BMul����F߂��_d5�s��Pz�B�f��ɱnNئ&#�j�T�GjSV�U[>{-��ȕ;i�{A^��kWQV��#ԋ�PM�0�h)7O�XXұS��:U~����_���5֖p @�V�q^g�D��=y:O��/	U#�rY�_�v�Z(m6��K�,�a��+_�8�5n��$���V�M�F+¶�4�39<�kOE���{�O�D���DF$z�K;_h�[å#���)��,��!�Nƛ�d�\`�{.���-��+2.忎��`t��EL>�GZ@m4�S�Y@}�ik��m�%^{uI3e�Q+���qyM�
���sYTOX�?�tT?Hd(Ɓ��-TYyZ��u��*M���n�jQ���rb����2\�"~��t�K*&�,�n�z�������ʾ���%xR���=�P�0�d���T`o�-�cE/�Dy��Y� !�����aa�B�f��̿��Y-kJ��������Ƞ�>�*���U�@����ow���2�`CY�S�.R�C�Q����0�Y�����~W�)��x�?<�����@�z�U�)Ǔ�m�J�ȟ��l$��Ӄa�?^��4t�Ϫ�G㏽�߼e5uHU*D�����B�!��*o?Y ��!�&M��A��Aڤ���A\�j�Ў&�0"�ރ�pĢ*�M-�����?��4;��1ebw�du�ͻ��N�lJo��6��(	��Bh��Whr�C%�o�jr�� :�eHy�O��#�a,m����'�m���5U�Fj]��`��!�P�΢    �eR.G�T��e��ʶ�#�KN�Қ<_�4j �a���`]Dƅ�d�m�dg ��fNpij�4ps�F6ƅv.-�;�d!�g���[n������j6��L� �N�N�0�"hJB�M�(��f�/���P���Y8���&T�4��N��d���w�O��S9Ky-:���J��$��bRq�h*J$�"+�T�;_��e	�Ÿ����uJ��W&W�ʳ�ܒ�!�jǏ���l��	���B�Q���WB�r=>�C���;�f�XE�X2چ]�v��K�����ީ�5UG��p�B�&��+��E��!u�.ߙ�5unS#Ɠ��l[�����2Jvy����;�PrKs�W��*���QXXjZ1�wUb��dV��Ƃ%�DF��U���1�������ΓTD,���.�H�o%�j4�*� ��e��V�2,�u7"
VB���C"��B�T譎,�{�~8��谕�U7/jK'��'b$�/���A�4'� ��[N�t�FJf����+�Y��-��O�_g����` e;(N�e���8�tv�ѧ�a�B�c)s(C:δC>��o��f�P.���vskWb^�9�S䜚�G��R!��䨒W�<��C��YS��(�Ld�������.��	Q�W�߰�Jy5	r�v�&O;�H� f{s��Gr�Ĩ��l�	�s�%�5K4=�1F�P�=a�F���,��ځJ(}�1���,��)��M�N�۶��n.D�4�ѧց���:X����Y��c<JY���J��J�j]�;�����9=s>�M�Znǩ?ꄒ�F����l��q�Ò���r�-8,�(������а9��屻�ь�I����t�7�X[�R[wx��f�}�:�����A��$v�K�qU]�A�	��&��"��v�{M2��7�3r ����ӵ�z?���]�_�u�3�fkĨ�D��2y&���B��(fqy��.<ZM�0�9���5�N۬%u!��s^ap���fF�o_w��٢AàW��I��;���g�~3�@i9�8R�dD�Bbkcr�v*ɐ�λ�.(N|��4�e���%=���ͫ��0�ܙ}��>��o4��~i(��[��"�AN�E�a���Wu�x�\l{�� �����!�uU��Ke��3x�8��\��0� xR���X����nT����t��2�(+z6r��]$g��ʙ���m�<�Mi�)6�O�D�6�"D�(^����>7USj;�Tf�k�ƦuO���9tE�����fPMV�����}G6D0\���"��m*�%|��Q\�����l��_��>9s�o�����$�j�|o��[f��F��k�$�6%k��fc�zA�\��y��d�X���=�!`�t2��jP����*BR3i{�d�R�Yp�B��G���d��;|;�A��0�X@�BY"6��}���+�H�n�P�&1�2/�m��/�m(CW���1�#�+T��q�ѫr��{�W�5���nl��P�~-���	,����͹}����EbXu2�>DA�Т�J'�����G�ԉ-�+�~�|X���Le�m�Re!�~�c'VPn�21���eܪ��&��M�B�p��w���O�[d��e�qB��;��t�L
�bDe��نQ�܁�	�K(��$A	�yl�O�LG.��6w�ׅ�j%��2#sdK�tZ��ŭ��*�D.���ʗᰯC���*u !�Q�ſ�B�$?b"���0e�$֫M��eg܂�n�RKC[e?*�4r����N�/GN�G*��R!�\���� ���a��ڢ'�L�P��B"�Ƕ6ej��T�ɾ
���}waMc��5���[ph����Q�������`k�_�����l��/��r KK�l��@t�R��+�)T~�t����=a�x�Y��Xl,�u���9� D�{))Cw�-�8)T�����`I
�@a�<Sn�ɞ*���Q?�K{����N��t��䃺�����p���]�xW���k���
��z�6C;3�gEs?���k?Y4�7�h�g�#s���Hea�����O���t�d3F�ݒ+�}^ʰ�֙���tƕ��q-D	UT�i�I,k�_�ga���� �.j����2��˽O+��̭��n�,(��Ҩ��m�OL��F��d�����[�5�����~1��5E]߼�Hխ]r�j_�Jo��p�E>C�.�N�
d �
��u��jקqyE8�呄S�E�#�$?�kh���}�]� ���,:Уb�Mۭ���-pJ�'=C�ŧ)�"�Ve]6v��rnMW,�O��àre���������3Ue��y5�S��Eq벬o�K<�R�9Z��(�8^w��dg �����~��=4}B��o1��V|�s����@2�Q�6 B��T#Œ) � frG9�Ph����FI8��J�"�y�Tfx�4���C�c?.��.{�#O��A~/&P3����U�_R[E����eDmnѠ�H�}{BL4���	�����*�A��DJ�����5���Q�!��� ��,[hQq���;ú�2�¿_��_oM{3\��RЙ,j4IL��>?����Z껯xծ	�d��Q�=�t;�)�&��P�T扳�g�<�
��4EjDW� ��W�Lcup����z [�5��RE�W`e���>G�1��[�i|[%V@O'<�7ݦXpC�un���+��T���I���т���%;�!�E��}���+��P�,��/���|��?����b�t�*ٜ�< ,Gb^W�g�L��,l��3fB�]�u����nA���B�W��6�9�!�[������i�cg7�`�|���G���KEFD'fJ��Yd��8�/4�u�K��@Vu�K �d����~�H:�mF[�E]!״ne6��8�����"��8�'Xv����_Н�`Ҿ$��M_�O%XzI��Ox
FSny�_}�U2iPޠQc�F� d�����;�$2���@4���H��cc+�@1R����u��r�`@ǋ �b����N6�t���8�����@�)մ���H]�F��<\0+�t�/PI�V��EK�ٙ�I{�����/IG�T��<�vD��X�����G��Ӆ&H����ҫ:!Y*f�.[��}O]ZxvIH�Z��%ʩ +�����~�W�A�[-E��sOI���O�YB�Sչ���S�%�H%�[�sS�>�-���˾���z��Desa|�lK/���yDÝ�0�Ÿ͢X���8\L�H��ؕ��i��d(�ڮ�����қBŚ}��c?N!5X�1�p�	������׊%�|.���(*�	�Nz$L��*t�S>�Ϋ/�%�Pm
}{��+�
9�9��o�f�Ty��G���*M,�n�^pwE���^_�+N����0�&���:f?�1�o�0l�W�MY��*�խm��OP�k4��� 4[`�Q�A�zw�=��|�a21��&h�&X�Ej�"�M��B��φU�Аn�^���^��b Vy��u\�\!E����T�q�G�oRo���TI�O�||Ԋ�͎���ų	/1}t�6]���4łl�)_�7��~`��l�F0���Gq��b:�Aΰ�F{�M�������g�H&|�E��h�*�T5;��pz�Qic��ͫ���X����e���:�aD~���4l`�i��dӰ&o�������I9X��km�����w�����RD�z}DA��Z��U;+N'�Ӊ����~kC��Vi&<x=Qۃ!6�>��1�������U����Sw��:��}���E}��-@/�����ϫh��ݑ��Dy�b�H��Ѳ�@1�s�s²���O�������)����~�0z����S�X��
��
1�-b����S��x�d�M��g1��VRv]d?��'w�O{�)h)�p>!����29'A��s�C�@=n�tԦ����y���bl�C٤%�&+��j�Y�9�Mn!ô��~�8�|/�Ϋ�T-�eC'��?!z'@�A����6����M���hZ[�G�;��    bu����$�&օ�ZwRVr�� �/��'�	W�3
�D���	����b
�T��YX�i�2-�s�9��4z��y�n�Bo���`�|<�R3�]��>��s���`����U��ֿСB�Tey{xLp���f��9ͪ��T�
b�xCu��M�,��&$�����៧Y!$R����d�BM����w��Ŕ(�췈��|���߫݇�����K8lIƬj���.P�;���>�����a}D�{7ȭJ��c�`y�26�Dh��i�~Al�J����I�a)slz�\��6���X�=)�O�"�h��('÷5��p�Bɤ*�u��}<s%^�@��#��A�����t��[T�_��2_e�aRNq*�W�m��vJ��~��.�<�@h$Z�v�笠���(.5���'�/�8>]�1��ƧͷEw���_���M��ك��~ܠi�z������՚����W�H���F���f��EN���$lK�Y Wa\ak�\�}RF���v��{����C����_E�'�k 6�evV�w�d�qj/mӍA۪��?�W��A�*#� ��G�@���k�uD��q���>���k�-�z����֛��>��������ԑ^M�I���{�\���=��گ"1E+�(w�ڢ��7M��b���k�:�8 I`�i9��o�
���G������|u݅�#�to���F�����%4.���Ǳ���ⴜ�KP������R㳟��ٷ�~�fr�8c*�:��'��mL���f������V/��q�p�]���ȟ^��=`<q�0��)�m��	�������1������*S�m�/�iἲ�:�}(Y;x���&�y��ń����b7�4z0͢Dnb��d:!h��~�m��4M��ّ"m2����v��wK~!��L�>��4��vmU��&�C�i$9��)�HE�Al#�T�d��=�&�+�NUp�9��N��2f{:�ϳ�V��Ӳ�ҍھ�.��o�l"{ؐ@��5k���20
�)�&Zv��2����o�۾_ �.'���C��Y�[�:9���t�v֠�^�j�ܦm=�)����. �`a/y��U�6L�3'�IZ��MG�p�}	W��}}�y�~:���uL[��>!�4��]f�f���ʺ��d�vQ�B�k"{�~�b��D}�wW��~�z}�Sy�{����`M7섧�tMc���6arm֦Ypo�RP�&\�	b�x�k�����R O*����Q�^��"�ixu�N�q|7gJ���u�$x׮Z/�G�&�l!�(6���{E��s��m��ډ��	�Ħjr���l�����!��V���[�72|� �r�?�q5X&���-d�I	����w�vtdY=�i�!�#i��"��so��o�xW޾bpEe�FBZgo�k�������T�xsE>�,TE�m�RO�:�����++Sh-�d������a�i��_NLh�z=�_��I,�0WY4M�8;���ZwM� �પ�)r�3g"�.R��4�PɇX�Ԡ�@�zz5�n��,�Bm��}eT�M�Vdo(�t&�$*4���<;hs�'1��)kg_(�i��݂����Y�Q����L�NQR�}��P�����1ؤ��gQߋ*�G���^~��b.p��<e�ŉ���� �N�����4r�"�rZ���<�
Ϊ$?�}��)�I�F������~Á�x�σ_X4��G~b�I��5���G}����`� �wxp���Ee�fʈ�������K|YB@�xz��JN���
�/P�w���*'�ګ�;z諈��w�V�ƢiU���h�U�5	�W�ͽ���w�[�nR��+�=`�x��f� ��}�l>�bu�]�$#G�
���ߥX��Ī���!]UT~AE�]��3h`3�̉a��#͏���X���(Y�peY@FxU ��Iޭ3N.�V�!�[�5T5xF��1�W��e�g��WN]q����s�a�҅�bc)�G���Î�gʌE��
b�V�B60����a�e�9�NT�T"�]&!��)@i��i�ҧ��v��l���mڇ�J� ��v&;�C�D�dSt��>ܙĂ,ɬ;�z{�����	��6{���ۋ��0�/�`9���|
�(/y�چ�,�N'��s����{=��
��:Ĝ�`4}��w���.e�{ �u���O��3o�}��j�ܓp1ecL&R&�d���o������A�pM��{�3�?����Dau��5wd*�u*-��t��Yե������$�>�u]�Pe��	�핎/�D-��3,	F�T����,�Rp�ý�N:�������v�-PX���5�O�����7o��I���Y\B��Lb�T3��sK$�}�\S�2{�~:��=>Be�����]@h��.����a�^
Z�V���֠���2Ulٗ���������SJȬ��OL|h3��=�,Ǻm�/�ƅ�lt�2���u(��F�h�-���;����k��5/4�m
[u�ϑ|�"tX^V��Q�N2D�K����=��%JC�����R��E[H5��J%07V��
�pt��S�DV?P��C�H���D��B���R�����R|w';긢��
�$�(Dd�$&:V|��_���X?���y~��#�K�	c��t��8u�&�DIY��8#%��F�C�p���Q��]��1�ȨR�=Dϡ�<ф�"���~R��Aj�:J"^�;|/�|��������N�*�)��,�@�\l#Li��kv'�i�f�ޞq�֘��c�m�މ$��B�|׋9(^�Y }���I�f&37٘�/���MQ�:�L��v��~�L���<d>�`��9�P��!��&$���(�+ �p�1��,iL�cqy���ؑ��p�9����~�8h���Iv���Ćf��ICx=�HzP��0��B���|`���I@���#F�x�;<��I���/�B���?���C�� ��g�X�S$'V���:Q|m�;�Hj��M�Yj{U�!jFZ��֍M�i�l��	���:/Ԑ6\���3WC�5�ՙ֫���o*��s�L(��Q*��P�� ���|}Bg�%3������H�E^WZe��'��fuJ�P5��p[C��',�B{|��S�Z�)��7��f���MS��Ⱥ�u�ĭ�D7�z~dle�ù���u�5Q�B�ß-�ǌ��7<O�XF?�Y`���S4��m���u��N�&��{�%�'N*8u{�I_��8j��*D˧���1Ʌ�Suɛ��j5o���ģ���j��
��_��r2V�wsw��
ߧ�����1�?�����6~U��t^d*5��}j�⽽�M�k�WUb�J2��f�Y�;]Y����BC�^��� �1Y�\�-=2Ac�$�vS�⎽�,f�gI�T�n�����>��}Y(R;<����^
��VLG^��~�#���]�/���y��}Ó���4~��]]C�F�c�כ���Q�l��g����������u����U�����R]{����~ac���~w���>J@���S�xbGa�X�M�m�`x�Uqy<o�N���4�o6�
ݥƿ'�z�u����5
�	O�O`߁�ul��������0�>~��%��t�H<I&�߻�Z��7��4�y�	�G˛$%(l���r� �F6��	F��>	�����)�I���+_$�!ҽ���.�3CU�L0S��_�T�i��ѿ9��q Pl��{4T��^�,NE�醛(�����f��eS�ZK�U���h����O�p�����v���R�X�Һ���P���M��|N-E�)�:bV0cꞵ⿌�=��ǮV��N�?�j���V19W5Y�i(F�%DuQF�D�Qx��z@�
91p����Ԟ���<�7�҆�y/�`)�8��8=:�FjPa*�����!��S���c���&\g� �(�'��82Y�L�j�f�u<�YMF��۲X���T�ʘ���/Lܣ�}Ud�^    c�Zl�RR;�9���r�EQJ��d��~�����fcJ/�/��{32O��B������P�������L�8�(N�ZѾ
��4�@mZA�"ÀPK��$qMP봗�����HD�w�*�_.�l������CL��T����E���s`,��������5�nV�l��GF���3�쑸$r�᪒�2L��P�J˱L��W<���G�q���`B%�zR����\|���^Gd�A�BdFu�<;Ϧ(�&mY�L�ߘ͒�nK�r0��^���n�Dd�K���y��_�0aL���D*�/���BhK ZJQ�D��e3`��i$���&��������4��LB�b܅75��ں�l.�h%x��7~��q�ӵ���xE�Cu�zg1���	*�~?·�UG<@��8<��W$O��Veq�Z�jT������4d������=�w�<��%3B�����<���A�ޢ�S!�B�_�?ϲ��`�~����WCC����o�d��-�X"�[?X*��,|�"�-O���J-��`��Ix"
2��^o6�#���UlT�{����!�+6��t���H�����
�Z۳*�u��o�b����,ߘL����UQ
�n�5b��T˴ŨQ}����b�m��Y��������8R�_��O�9��ڻ���dʩ��l�66��1���}/���P|E�q=W�*E�ux��\����9���߷e[��aIM��/�:����Y�p����aD�Ŕ�a�nU%�(SP(�e�4j���b�F��.��R����T�Yp����z�}��8�����q��r�K�������7�PK8�7}+1]�D�X��\�Ry�8�&�ë��]ҢJV�۸~�X��H"�^����୧;h� �Jl��&��*��3����v]��	(ۅ����~ՂFC���G�a��+Vl�@Q��
���i��$�/��%E�>cĠ:9\�&�$��N`x���c2�ĭ�����1����Sgo#�b�#�C"i��ߋWq���;;��泞��lK�*1�0��$��3}u;Y./��jހ�䓞ܨ-�$~r2KB+N����"Ւ���* L�&O�?�����x�x�&���ͳwx�6��;�����D�?^D.z�m�Ig�2Í-s(Z�X�G\��B���p��� {[׷�g����F�-��8Z��ǥ_a�Շd_�U�NG�؆R�]��W�t�՗�/�8�`(��M��B#����q���U��.�e�����'�o�d(N����f���<�~y2 �v�nn�{��p$�U����s��/��'!ԳU���8��~�I	�'���+�y-w�Y(�˫�ZK��ۮ�܂�`����`M�vp���
~��d_�c���Щ�,�vt��wO���"1G+���v���6F���f?��T�7�vQ�Ez^5����¹�.պ���!Nf�,m�p�Jlճ�i�g� ��!%�4�a�ׅ_P�9���e�e5*��T�tܑ��zFGV#��w�sq4���+����S���j����-H?������ϐA���a9�q��������MI7�Y��(��@N%�!-�,8iuYTze���?�&7��ݬ:`� ǴP��2�6�C|#�S�\^6[��85����6ȶJ��7��-n���b��p��.`��g���Ok�+�W*�@�ׇ�{����I$]ċ.�j�.�_��x^�Z�cN�����#=;B����P��ԐwO�~i��j�����U���~zdն�B�,��L��-�a$]����Ք�dk(M��r�JE\ZhU�х#��Q��p.��P�Y��Nt�Ц�{Fk��j�<�����}�
�fv���dG�5�,�ַW=Eh9���g�L:��<O���s�r��q�	�|�hB-��<zEh&�ȓ5w.�][�^�`� v{��)�|\��[x��:z�j��������E�P� ��w}��y���?�Ei4%�2��x��Bx��d�F&��r�� ��� � �?��!=��#���F���K+HTt�J�����ۣWUj�g\�}�j�?���?���<(�P=�3f�<b����=�+t�=�7��0&1~?��Vm���2�%��ޝ�0���X&�c�vJ�2mݜJ����z����	��;��W�u@�>�7��~9�Eu�)�Wa�4�L�|b��Td�wݒ�{a����e��mx�Ьj�����A�5�k��Ν����6����p8�}<6�v�]�	�Q��)c>R�3\�����<Ή�ל�9s�H�.��
9��s�S��B��b;E�0��_����ι/s�����,vb�Քϸ:{��Ю{��(}�R�T��i��
��B��m��Dl��^�+砝�B��]�'KBYC�Lb	U!�V���JP�Jɰ$��> )��S���6�bv�h�U���*٬�?Z a+�.����;���){(�؅���}$=�;p����ܷ��5�.�6ڑ�C�T6B��6����+s574��>��×��Cc(�P8W�[��en���p���(,<�n�J�i�A�8�������Ѐ�O�H����s���L�e���M��\*I���B�q���,A|�`)�p�q��
E�V�w@J���Sid5�؎�߮c˲�E�񻢆���!���HM�A@'����79�r~B�!�{�۷�:??ZUԉ]���=\��M{{�:v�f�O@�k���3��L���b��w���4�n�_�<��Ty�@{9|u���̶�)���B��;FM��ǻ^ 2�,X�3`:����8:[���T(W��fIj�U���f�cX��x��'�V�jV��������W�-}Y4i@��Ԯ؆.H��"�3���D��]B���CU1����PT������q�s��[$��n���j�R꯺�d����ᙖT10B8YQ�|nMh˺ry�i*�FW曵Yp���P0k]f�G� 2c��JA
5RҔ�����#ؔ�Vd��eO�������3��TUb{�T�?Wmݵk�Ƶ�~�mY�u-��S�PQv���0�.�0�>��P�rC5`J�:��f*�����>���.��M��IN��}��I�y�z$�\y2�kxKvU�������#�,d��Цgm�:�0n*=WV���"�k��F�:�I�Z�K@a�4��|�]���Պ�>�tP]O��DP�8��>�u7�z�hj(�ZHx�f�B�7z��/}�HB��(H9,k���(C��mxx�?G�;,����A���%���s2��� ��ѤAˊ�� �M��@�q/��8tž
]J��2��c>"b�ӣV��З�%��JS6�UQDE��eod�$��Im�B��;d�"������(�~}wVw9�%8�l� ���/f.�<O���0q۲+<�!�Z5�>�$~E�m��c	6ϔ{{/H�Qy��y��+�:�vuQ�$#��U��qUڪ�����A8�A���"�i�%��I���|��C�*y�~�{p�`��I~�,5�/�g*o�@���k���^��� z��
���!Xh��ܬ�?�)����T�p3%(�5<Gj��:b0�y
�p�ȏ#�?��E���Z��l��~��ܢL�T�� *�@��:�0�|=nX�\A,��?;���&��Y��}hU����R��u����w��r�h�R�d�s�y:{Gn����ɚH��L�ra#�Y��'� 4'��p�CK�����Yz�,�6�~�#�*ډ<�n��C�~��R@=́��7J.���17]	�)�dw�췈��Np=�2���~P���?A.1Ԛ^��,� ���a����c��>Zh�>K�A!#�\�*�%4;��)���b�⻶m�.8��U��&'tVы Z�
���K�z�!�?�p�T����N{�7��L����!2�T��.�'�G{�%)�{iŽ�?���;��?Cu{��;�'Y�B�EZ��t�e�.���P�*��)C#��>�y��QB2'��W�����    ��ϩ*[�eb%�T�uW�;� c\��Vf�M��(>Jx8#xX�(>R�J�	���B��S�u�GM���:�N,�;��}��
v��e�ؘ�](4Pl�C���u�m�9�^@B�c��<@��_�̻+�����z�l��Q�dBH��҆�*^�[�6�O�Վ�5�W��ڹ����*_���j;d<�A����a4����WjM�"SW�k��$�嫼)��k^Z�^�E͑s�ݓ#�����l2�6��)#ݏ��:�|�_8�b%�a,4W�4%f�mʊ�ބ�M᪊�in��ȥMm�L�O�@{�@D'�5t9� �ȎxP��P�ђ�]d]\�w��o�8�og��$���[�8�t�J����1P)6���o���;2:L�����d��f��U�Z���D"
P�H���'J�����V$�@�%�U����$w��D����� L1�� 8��wV���O�49�^	߻T޶�*����:���4ٛ��%���)�B$�e��[Aţ��+ޡ�M�4���5���pk��&���Q%�	���5��3e�@��Ц0��򵎙iE�#`\UZ�ؕ����QEU6ߔY
Z1ޡQd������m�q&���[�!��2V[���M �rp ��G�u0�NZ����-��V��⧠긔 �izVMnj�xI�v]U�&�~V�B��6��+7��c,�����@E�ؓ^���t70q C�u�1^k��	��j6�B6>Kߡ.L���H,A�
�X��vfAL}!V_6|i��̰���*9��@n􃪣�bsk���̕U��8$Y���Y��2e�k�Y���׭��,��Q H|��jr��x�C5�$guS���e�S����]��M��U8i���Mm
���y���5iL�W7n!G�t�<u2T��H�M��ς�-TR>����/�����d��`��@'���>A�ςNdm;:���1Z����F*��nCs�E��?��ٳ�$���!-u�!���)|"�ML�H6��B���f0�����W�F�x�����u�W�|<>���w�#�ʤ]=��tU]Wx��i*3ds���U����N��u��Q��ߪǡl��쮬�$���S��e�@�p@�nA�A#�d�jN�TfM�4Ux�`�2�4�R�Mb	�T�1�e���]"�-[S��I>�>	4O�6�􈽚pq��K�����Ά..m.H�u�^�\��E6oh��rχ�(� ��,.�\Z�]�vv��y� !�sHe�<f,�b/���Gc7�Tk���%v���(�?���Ȉ�R�I�
�ٮ+�N�;�`1�_}��,js�vw����W�#��]�LW����Uƿ<��� �h��R���7���(E��(�^*�L�Ѣ���V�g-���r�Q�]����u���9�wR�9�.��4�^��]&%tQ�D����6�#N�ؼ�?��ӠQ�ʁ\���m� K��}2�^h��0>�W����+�e�M�U��8
?���?�q�(<��X2˘L�Y��qH_���tĚj�_m��v�� �i�d��%��l�j��j��X�J���8�%��&�v�K+�ɨ�;�e�O�C����}�@��Ɗ��-���Q���Q*U1�0z�Zx|p���L�7)F�I̚�Y��u}�xL�Es@�0�h����*]QoT�3��^G4+];���P��MQ)�D����B�|�DPCz��Q��L�:Qm/:���d���F�������jz�ǔ��<�2�Y� '@8��\�����Fx�G�ǏxJ|tQ��)�(���kJ�*��B��Y�F�ߚ���7}ɦ8[�ڗ&���&{�Ȍ����>J��o8�/<���}�,*�]��ϋ��]Y��,'C����p�Lc�%N6��"A�I�v��]�p��il^%���LQ�����͋Z�6�ʈ}�jn4��i�=p��X�q���!4��ԁ}��z��y�Ҧ�t����o\���%l>{�r��J����G�#��������u"g�:-�,���3eo0�-4�$Bu�{��❘���9��x�[AP�2�Fc�����V���A�Xb
T/Ӕ���PF��)Z��b_�]EM�^��t��ſ;a��lPg�ͱ݂@��J�[§�c:N�c�^!J�\i2<�~y�3�+0�����)>��- L٪*���H=j��@x�7(sU�/ �!�a5�܌�(��/�@|+TfxW�A�0�"�O��
��*���NA����,�������q���"���h, @�;J���R�ÿxf/�\A�B�J,���k��n���1Nz���>␄� �E}#�@�ǎk*  ��@�Ӫ�4�Y�LEs���X�Z}x/o�6���d?���64�2#r�� �6�	 �8�pg�j|mҦ�d�2����P�+�RC
|�"`� ��@����Ce���G���O�g4�HJwɥ�,z�)���̺1݂�������L%�I�����!�	]v(?�}��)غ�d4Q|�vr<��JqM�Z+����:��z!t%�6S� �UQ���}�[�A�����z�)
fI��$C��g�7W������=�٬��\������i�؄F��T��M�&��aJ�f�Yk����Kv�ye��W��~M&�q�����]�'����r�h^�����:i�uu\Y�z�Z����B]HexG�41�y��#���sP4Mp:U������h� M�u�����v�u���AZ�'��i�:P���.����_!�W���ҋ����WB9��@�^d:�2�B�74���~���u�$AO��-/��gk,��0J��æ�ѣ��Մͷ����s�+4	Wy��x��&��A*�[��!>���I5.�9{����A6CTG��4�q#GH�GW�.ߩ����:�Le��>����N�"t���АQ�g�x)�� �"=�ɋ�>UQ�D���њ"���CU�~YCUfo�%t ���ֵd|���Ħ_C�r�^-���Rp0F��Z��\���q%�iC���h��/���!��*��K'�M�K$J��W�ƙ�p�TvF�z�/P�
�]%D+[�lPP�GT7Z���
��75�0X�L�CD�Ge�tA2#�BR��YdĠ�Ύ�Մ���h���^$Ale���DaꁢŃ�٨}�����	P�	�O
�C1˳��$�"��I�֔��o��v��e��
m}�%4������`���4�ebI����$�n�:.|�+�V>����P
6�#���}��-���4<�X�_�<�v�j�k��Jh^��Ue�Y�$�'BV�=T�_�ge����m@�S��Y��`NHx������o���hJY{UM��?\d����D�딎�aw��N��Ĩ�R{�<����@
!�/�O����н���u���L��n�Y0GvMw�&G!�0�/
�hDq=r�Bx�ۺ����)*���.������s߈Mo��)#�������=���F�加�	0�F�X��\���N�<���⊮X�i�[+�ք>A���ֹ	�
��/����+��*,j�[�eUZ�c�N�1����I'T�h�j�_��+�f���/C5�7�"�'ѷ�-�+h��S�	�\����g������;\\�� 0{�+���Y!Օ��Y����iA��]�3�z|�L�����������rNf�������+�Z:0��SH���=xS6�"f��~����� ��:�;��v�.\k�����\�}�&S㉨\;�a�)�"�wӔ]�6���-����E��Zu_Z)#�WR8��4Y��X�Yd(|�v����:Md�[���t^�3���pRE�N'JS����Vgb���?ǵ��sog�;�*��b���خ�u~;���R�"���1L��e�+,�p��,�#(C�LM��}`��s�ZFxۜ�Q�򑺌^Wݛ�ׇO>qs��wu�] ~�kJ�C�!�j�I��JQ
d�tF}G+]`�t��AO:z�s�e8��lSWƶ=��
S�.�K{p���Mm0�|SU��\�gC���(&�΁μ_hY3��#�    �w�۴�^?��<!ڠ@kZf�ΤP��s��0�����;�a>�^�*8K�0Ӈ�_� !��*�xDvJ�z3�l�?o�wcǮ�HϠ)�t���ۨ�*�Nm���{�( 3(��ן����4	ZIʠȫ�T?B�䬢��l~_��J>�P��+��?Jm���L�+7��J�mᶷ��꼲J3���R��LC��B��|~�:~�,����i/��kO���m�F�k�9$;�\�8�ov��p��#�Dv͜m��4.�)�ծ)9���~Om%>:`�M��0U=zY��*|�8���y;altD�R��I���E��ȃ�����P��E�zh� ����P ®�-L� ��æD?�QL�D�����0I�&ozj����c�����k���U#��m��2Aq���"��W�EQ��=��ɡ<0�D���o"�q�ר揀/����B�1�NY�&�x����Q�U�r�o��]Md��2I
�k�*���A2�A���Ub,2C��ݟ��YC=e}ڽSוi���tn�d(T��Z�(��0b���^����3?��!d���}�҈�џ���j؆'5N%��4Z��l��a�Z��]��ᅇkԯ���F�4�@�Sݬ�J��-�����U�����~F�hm��&�$Nz��l��r'�\OQQ���؎�l~��D��\��`	0���+�^���o��GS���B�O0��5B!�=#T�V��?t$�Wt����~�,��NG ���<�w����5�/2��Ϩ�}�Vץ�\�[�i
#%	U̿�����S�
��Btߞ.�uS��Y���%.��͋|��͂3؄/M&i�K����Z���A�K�
��Z��@��3�F�� ��,� ir�aP�S���9@��C��7���dP�X��Oe-���o�@�/���x$�
���az'm"��Q�(3�Hl��h�F�3�sQ36�� d�G��>���Ƅ�n��?SN���+��CF.��χP���E?,�tz� D>NJgJM�}B�B	�iB�˸��\k�n�qi�Ά��Z}_���'��K�.�>S��$.Z��=ˀN�n� f&1��} 'k�
扻ɋ�8؄bF�Ѷ����PS��	�	�;.S%U?CPu��DDuxt�7G~���MQT&�Xo2	�0�_p�¯52csʜ��r:
�^�wSHPr(m?A��b�2�ݾP�\]�[w{	�T���I���ק�z��@1IY��6��ם%uG8��f��ʢ�i7�ɲqm�NDc�Օ�ٙ�H	M��O�m/��tdT_���
�1e��l�$1j�m���VNp�f�<Iٖ��P�<�w=γv� p �Mh��L����27im���k_o�D&5���$���'VRI��fQ��>�{��}��m����y>bi <���L�4Ի�2��&�>Q�L�q ̌�&C����+'ZTN#�K�t�D�jݮ��¦6F����_iJ'���"9�If&�������őDgҐI#��VMM]6�N��cg��vxRӘZ�I.�g�W1��j\;�V{�秾�8� ��|W=d�ȸ^�e*��2yb>��p�zkm�^�y(�6�yH �:���������^�@�C���g-?�ݔ
7�Lw7��H�E�nWo˭1�ǭ5��f_d?��Bl����E��zI5��.�ŁB�?��2��ز
��o��E�(Ma3��~���
����ۣZ�_�rϗٿ�K��GW�Y3 ��}>Jg�1��_ �z(A)�؅.#O+��߽)6��l��*��y��
��8n�#7��F�V�J��RZ����^��ҏ<1�]㠳��{"ِ����� D�.<���{��9�9�?���yr���j*����L��h�KG��D2���0S*r��-*�vܜ����5�E㭦f;��\}�sHJ�p *�_�*p�W����m��I���M��LBG�H��H|b��+�D& .� ���R�Tq��'5�:���
���2n��R��J���'?M���x�'�4q��j��Q��Lۥ >:���a4�f�(��0�p��x���s���>�I�ݱ9�ľ���vLϳCh\�Ҫ���5�����ZH�!t��J�\(�|r�����y�bh�Q�tԙ�F̆¯N���K�����U���ˉ<]��~�Q8;_���!b�'�и����A���n�����E�4��G���(*���(�G�5GK���wl� hW'�U��4�>/lb�k�aUh�j� ?�&jIz���#���\u,&,h �����pI�z{�������r�	��dܨ,��Y0��&�b�K��o��^����u�� �>6{���%��O��؁_#�
�������l���>(ŎN0�ʭ�a��F�A�G\�PDͺ�6��nlx�$�E��˯�K�ֽ��>�����m�ow�2pَ��G���*����TE��Ie�9��w}���"��*B�e���aE�ͭ(Xr[+�.J�Ύ�u�ɛ���􏢥@�{5|e�FZ�C�E�v��kb�drM_����(�(�VW�o�� XS�*��J�#֨b�r��H
E�~��F��x����v�8v�NQ��&fP%��7[{�VB�X/�)��8�ы>�~#�����y��b��0�$��y��.P�ZF�6$��I���GR݉a�W���F�(O�̆Y�JW҈�%B�ڢ�
颲U<B.!���' ��ľI��O<UG	����R"E���3����vi�5xQ��$�P'#��U޻�g�����j��'B��-���N޲��V@�g�'���0�y���"�i7�C�LΨ5���B[4*�S�x��Ρ4��=qZ���@l����PT�̽F�� {��i�{o1���^>��-vd����B��Ebe�d�m��Yc��*�X70T_�����x�*45v{2�S�ю^�X"(�c��G2|�/�ۺ���D�V=�&��a�>jV���8��ō�Q��S H�*�2�)˭��,��ub�y����[����J��M���Q�5MP��?th�Z:�
���/;�ou�5�Ղ>>q*���Sf��P�{Wo���Z��M���H�JX�����?nz����EF�ĘU�?������Y��*O�r�X�([���d�,�#i��I޴x 8R��V�?@*vM�a+͢Ԡ9N;	K&�Юۭ�=Jezc=T&{��n+�$_��j?���� ��D5hJ�U3u�A��j��H��;��LFc�W�T��2�����GHZЁzd�x��$��uw0��Z�HO��f�!	���Ll�8|��A�8>����:¯�*ʊ��?DV,W�'��;��̧w���~�����OS�1,��I��j7!��&�)����蒭c��Ŋ܁8My��"vX�	_���}�2�+��ܒ'�Sl{[�����8�n\��<�D �OϏ�x:������!;�bT8�|bK�T�(�m*��k��4>����p�eɨ{q<I�u֨QN���;��9n67���bH���(~���3|Ryڥx:�5�t��*W�PSg����`$��A�o)�������`��3�����[��.(!����m|j�A���y~�Y���k|��"W���������d��h��S�*���W�w2L�;N�b$���y�.�����0�df�]�;���B��m�&���0���#C)/g��r�LD�K�O4���~Oc<��ɤ^��V-�2�2�Ƴ��D%2x"p1������V��oCRڋ�oԼ�u�[,�n�D e�2-hGo�ъaZ�� �n�k�N ���UY){�OF�R �m��k"���0��y�^J�Y J�v���@fh���x�rw��1u�ش}"`H|*��W�3A�Y�B��_��ԁ���`q=;�6Tb&-�#�\�:|r������Z�a�E[s _�ZI#d�1�%�Jp�"x)�r��*��0��7r��&�.A�y8@���������/t��5N_�F���    ��Dt.>���x�\���^�45`G��ǂ����t��s�dh)��>�AZ�PEb����!<�x\cW���Qn�}Z�ˢ(Ӧ�dÔu�����`5�gs���}��g=*/ �+��tդ���4�SSU�}�:�k���
f^��_U�H�C}=��	���n^����t��U�w�q�)�:�}t!�&q�r>�J�Ӧ��w�
g+��>�x�*�p��Q��rD�*t�;�(�?Qa�I�ݞ0��ۢ[����H��ë�ENt���X����^BcM�}�=r��BhB�����-D5�����/t���n���RU�-��,���.�"l�dt���rz�E��-9Cni�>�des:S'4�J6}�������4V0�ȳO��{��O<O�C�rꇸu�i�`�(�^�_"b��>�z2�kW��,�ǰ���>-��V�i��?}��B_.:���h(�a���OA��>|�����v/4st�������u��+3�w)|C�n�a@��)�!�M��%F�h��չ�&��ȁ�V,"a�lەj��N޾��^G�dh�Ou�Ōd�޺����Z�T�S��-:_T�,[�^���0ُ�����}\:]`�#���+���y?G,E� ������aл�� C�*�+<���.����^�����f�i�54��@�
�m�,���o�n����5R ����O�v�;* 
k6ZxR���Kh��?���;;d��r	�� :�3Ù�R�_�Q=ItU���*,�6K�G0�4�p�B,?GMjx=�W9͎��}�ƖL�����[P�4�����/��H��n򑽛�n.��Jula��M��Ƨ5^J�>ҵm��qc��(9���8?�T���"P�4(|�c&1!)�(י����a
S8�t��$4I5��Z$QD�݂�Sco���~e��t�L�+K���6c*|�s-@d�F��{z��	����/�%db��l\j4m*V���t�� �.qi�/��_N�>ج�Eс:-۝0��.�)j~���X;R#l㡝Um&4ZpI9Nv/7E�-��褽̳�)T�����=��.3@����뚴�dIoS��_�[�İ�gI��Z�1J����� �?n��?�d�9��han�Bh�cA��kO��uϻk+�IF��q
�����SD�m��v�-\%A�(�q5V���p�V[�$n������
������F@��8{DS_�j��Y�=����Z�L�1E��m�<�nw[
�L>wב�3��f@o����s�>z�^�~�oT���A�����m���p��9;�� ���'#plL��$g����2�1�����7Nū�ɨ����[7�PH ��N؈�~�$wnl��#��&�iYe�ϊ+L��$�����Z�<<�J�⿗a�ߐy� ���ub�4���I��]wU�&��_�K^�
�PN�Fq�d5+�B��b����'<Hc�׫���;�*g�P.&��MV�lj�ַ/�B]Yz���>p5�������jWo�{�,� tAAx�,NMA���0�i�%|=��Zl�\�Gw�HJF.�I�JL�=If��8�����M�5��G�6�*q�s%l���W�J�kxɾ��h�~��e��&O��\�y�f��i7��(�7�Ӡ��4.�Q�>"���X �!�_�p�q�=!�ܯ�۩t�Ǜ���o����Z�����$�2=��Ue���G�	���=�Ӽ3��qeb(\2��[7H��,�ν�<�!�]�y6����� S%1M�T��W~�'��5��>7��`� �yY����:�3�AT��ÐD]����'�.S�+���Y������7[�#ǲE��/�h>xԔéT�NJU�2Ӌ��;�X1�����������7������L��M {Z�l����녲_�
���~3�ɟ��:t�'̭���ψ~%,)I_������/� �øb�~�&
[K��G��Fɿ��R��A%`|�u!|SH7�����}:3�7Gu�'�L ��_|�*O+�#�h������ܨ�H]d�o@.~t���J��ǹ�L��eQ�����`�R�Ӫ�ȓ�O���}��K�w+ڂ�#���#hv�a�Y�
��Ȋ���O_.�WW�-�L�U��m��Q��I�4@�T��/��[}� �9w��H�3ǯ����̣hJ�r^�2��W� �Q�����ߧ/���3�
�X�Wt�ÔF(Ja_M����a+8bY��6�Ս&V�ei�-(�J��%�U�F��9sf�ǋ�U �a�a�(*��ϛX�b4/RJ[�=�u�]�ق���L*Sq�ྊWqs�F{}
�b�I��}b��z��֟�mj?��4���!�ER�c}��n�1�v5;%d��W5��
rT�!+��e�� u����<�)�U���Q�c �e|���.���6M�w����a�!#ʇ�'�k�⠕&��
����:n��Ӥ�A,�dU��d��j�,r芄�j�R�1����j	�¸xvV��p���8��V���BYUg��{n�Ox��lwbt�cj�����I�)������N�*��ꊦ���/U��ڧ��J��Hqd:tl��Ci��_����boأ�DwUn��ǘ\�a��%�*�h�Nk�G������o�<~k���[ۡ��r"6�"�Gh���5�/;u�?f�5�-�WZ
vuk�:]k3������~h;,Aݨ`��b����~�h��=)�:����{��� m���_g� �bk1όܦ�Ҩ�l�^/H��ui��,y�ʓ�iV���I�2z�a�]l�1��*�DU�ɧy]m�Ȃ��&����7�Nm�X�2O~BzEr���ݳ�Q�`�:��}�-���H�´�﫯M��&u����h�q�t��qÜ��H>>�܅��D�Q|����H�Ʃ{�j�@��m4GM�H��,vY!�q��x�oݮ��/O$�?���;|#u�,��K�a��awóќ�j2������ߠԥ���x	�'2��z�Ʂ�Bw_�ێ��)��e|��Qn�����#J�q|;���y֮D|���߷S���5������t<*��AzB�흠
T�OY9##_�.�g�R62��t�΍R2�f��	��GUo�h��\���
�H�G�����Ї]�f�z����%�*�|i�>���f�_�C�� ��2Z�6>�Pt �<��r��y̼��D�hH�n�.�A�En*����>�-㘕���J�"'�}	)��_bg��X4<��P��/��d�6��'�+����I��ӣ<=l�������I1̠bC�g���qs�!tً�Nw�~��+
4�G�"c1�,���}|9��u��|���q�ҸR�I���Y�����ff�V�Ef�Ȓ��[�^����Di k	d�DD2E�t��F�� ���Xeh���&�>m<�q�{Z[)vOON0z���"�1b4�^��
�� ��+ɺ���+�k�D��	�9�
�������)�&v�F������.'�H����W*�ߧu����U若K>������Sa���JH�"M#�>O$mL}�&��`�g�Ӽ����uڸ�YU�͂�ڪT)��� C%�e�����N��́�B�e]U�cEU��&���Ef���s���,�ܨ;�ڧ%ѽ#{��F:�,�}~E��z�"�)2���Y�$b�͊�/��.�"��^X���,� �����h{{�쉴�Z<�ΣeRB�^�s|_��[p�L�ޮ�"��~f��/����
����<꙼���&�e�J���rSg�[�JE!Ve"��&�dnDP��t����k�e�O�\T�| /j�i���nO[Qs0�f�]�2�Ub�d6��M%0��J>4�gq�A֍Hl_���}{�@F�nCx�=�S5���"fA����F��P�@�VFSd�������K�>��#j���z��ק�rc9��^��<@��Hj�#�ٛj�n�N���+�p9ԁU���M!X�Mc⪬�l�mG�����7�Ĥ�U�ge�/�4���1	���%��Oݷ×�e�-�r/�	ww��    	|�np_~|�4����<є�z����x�2�O����� W?@:O��_��c�x����q�uI�7i��}Nn��4�L��c�_����Շ�8���鋂���/���Kro�&��X�X�{��w-:��W(��TJ&,���9�]�����#K �A'@<\.�D�I�@�򟜲���C��Sock���i)0R�}E��@�]�c�MKR��<)���)�@�a����¡�Xz�Ư6�d�э�����,!E�e_���<	��J�[~���.�B����{���/n'm_��^~���_�4[g���:���k `���F�;
�'$h�]���<���"sףIe��_�e�:U�:!EX�íd'*X@���ZS��&���3Х�O:Ӄ��@��E2�R�o�Զ��d�U�T6u���A0�7�;��lnC���7*����-)z�pi�jDG�l��f���bs��*A鷴�u�;Ȣ@0�O!L])�`�1�sّ"���\�/�QY�Nv�|�k"/3]4�D��	�����Em��z�+���`�0�V�p����,�e^fYd5�huPo�OS�L'(u�|���K'�! ��M&��G�  �&߳��Ѝ �`�.�>\[��q�*d>]:��a�zdg"�)����H�0Z4�!�ƿ���U0�^ᣪ*��+#�D��>a�A){l����d��z#�G)Mhʺ{h~lY?��E-�TuX��|�q�"���?�@�m5`+�y.���3f��s�ˠ��GU���T����6�R�f&q#����*o�
Ot�Al_����?Ų+�l ����g��[p/�������{�m��>t� h>�[y�`iAH4���������A��U��L���� fuf4f.	>
���*���-#P̚B�!v�a+8�V�����Ϸ�&."��ǯsւ�d����I�Oܟ�>���<З���( ��G�|",h3��<�gĘ�Y��6�V��&K�ր���Np	N�F�:���*�A�Ku�����4�E��b2i����Y���S9l��P���WF��g%��c�&����j��6�̂g�_g�f��4<��U���H>ǣ5 :
st`$� ᪞�Y���/aCcnQq#�Ě1��,�"3�T�I�gPgB��Ym�D�#b��MP}d��&�DiB�7��n�h�kTn�:�@�|�����7IQ��l%i��G�-Ҋ��AE(��.��9T��k��>��΄�G�>��.3MVAkI1+q�q�Pc�5��V&��;-��q��`L���`	Y�m��Y4�P,h ��6�W3�\nO�u7�Zl1P�����U��'�3�
Җ���Ɋ���{��9gW�e\&e���IMQ4݂#�l8�U�aX+��!$?.�K��0�CG�[�y����k�M7���ҦU�ϛ:y�w"׶~�0�_����2@��pj��}�3lZV����i�<
p���l%m����1�'�p�V�c��x�nDaL�,.����d_�[�� eu�ʯ�&���FT�p$z��?`��_�������`<��=ʤ��-oO�6��=s�[���'�%�`����ʚ�.b K� R�0=����~��D��{l�f!�S�Ff�we�uQB���[b�k�l��Z:s!��,ڨ�|���aV�Y�8T�A��u�ޛ�-6��ȭ^R=OJ�p)K%�5�������c@jc.8��K>�&\�2��`�`���@"������ש=i�MV-�I�����i�``!q�*OsO��w��<�sBaJ��*���Ǥk�qڲ���"��P��¡��T!��A��R��{m�3Jwp����t.ږ.w2�e���{8A��Y=4"ʃu+�A�yԂ��rD^f���?"|�y ���ۮƛ(��^ ��U0����n,XU����N5��1pc�V��F'��Q�e{o�º*n�b)[�,��قw�N�R\���";뚻�?��S2eNg�DYm�� �"/_�W��2S���(�ܚ�6saz�A|x�� ��9�vGз.(��y/��� �f�h�:K#�b���8',���D�-hGdm�v�k����-��`S�Y�aR��	jQ�6���\�|n��X�f���^B�������]�r��SX�b��r ��g�z���&v����#h����+�D1Y�u\ĭ-Ku%ui����}P�j�1,F��!r��A��X�k�2�0�޸�?�xb��¸������#�l|<{�d���LΧ�@�����7��+81����o�M�u��+T�0Y�i��\�.�}< F���\�ц18�H'�^�
����=��t�� 2ς�4��Tc�֛�n�����L�aW$�M��$�|�	x3kD��0�}7�8��]�o�k�չ}8w�M�������XxB���^F[�ە���gHF_*{{��r%+��*9b/Ԑ�pW���y&Ni��d�%��M�����ۃ��
��O�g(�l���Qaj�� 晫�Q��46�2��WQM^ݾ���W�Ҟ�N�a/z�>��/G"{�RH'�9��l����7����53b�"	����W�.W��2�p&���7݁�'!;�9�
��3�� ~�-n�@�jDȇ���	hsü�\�J�ٺʪ۫cWN{N6	����K,�Px��؇:w�Op�6�^��]'bw���r���b1A��F�HM�J��L�����+L��9�1[:��`@ר4'�pp"H�ݩ��j�`6K#�a>���5j�f���"{���&ۤi��i�߈�M
�@�3�����/V�*K�j���J>q����+3ۛ)��+���Yp�Ku31i�� %ǖ�t��L#��Z�Nq�a�G������H�0��r�����+6h�m�SU������P��$ r�%/A:0��6}���@���B�W9D����{II�v.f���GO�`�]O�q����n�w��:~#�� 2�Ӄ|o��!��=�վt@^����!��&�k^x��I�0�F�AS�;1&�)ڊ��z����
'm���o �}3�S��~�8*
�9?�?j(���Ω��~�ټ(r�"�f��*〯����׾��YݤE>$2��x�ҝ�#��{���;"����EMO�1�u��MM�Gi��ެ$���B�ĬL�0@��X��R�}��L��n l�T�tB"��qV?��R������5�\�yy�K-��YY��Ҥ*�g�*�����MZ�Y��KZ�b�=����$�I����9���y>�_���L�=�u򙜝��	g�҇��7O��-�? t�{�%�q����:E�G0���X_-��lV;M&N���c�W��}9r<Ql�.�*�) �ߞ�Ȧ6w�Sd��>�KF*�ZJ�����ۂ_��A����R�hb6aъ�l�I{�;�B�K>H�5�l���B�D��~�hW9��ido4<a^�n���ã	3K�_#�k�P^u1�y$���ѥxp<><���Q���L�s���!;�HpzaE�$���c)������ �;brQ9�(��t���%�����Ӭ���[(�(*�1�3��ͷ�E����fb�a�-	��+��t�<_�#�H��殔�b+�G�b�(�3تAr��=��sx��b!�;M:�s],(֙"��-��H���8+mi%�E�ǀ{m��K�\�H�K��t���s۹�q;>��i��ҿ���|Pp2�J�uY�A��T��2	��r���Xc�8�ܵi�$Zu��1���a4��+�|�u�5��B����f���H��ܙ�æV����ƪ��-m3�7�Rhnn�G�&�z4�QtK �����֧��@��S�����D�u�"u��������sA� 3)�3�/d��~�?�a$`�)�S3��3�8�*������*�(G�n���09��n'Z
�C��zX�	9�9�[����4c��t�~�2U��+�%��3��}v9���IL`��5,���V`��+�`����[�Fu�C�uY7�(z��ǣO�r��7��=����$h>Q쾋C�W�    �y3i���ǀ������,�L�f���t.n�ڙE%^OMt�c"*�݋�{2�Rpp`�K������sض�u�A�3��/��]����Z��\2�E�C�JmvQBݙŕe�Z�Bׯm{{P�Y�$/�h��6VW��+��pId��4�/f�k����li�E��q��z�ʁG�D5��I��ݒ3��#�o��󺓕��<}��L��	��[��"n�ږ��SY�fR��e)��<O�B߳���
���S�ʅ�N�Ds�z�C^Ο�m��Mt�Jy�E����xٺv�"ys��^�6��[�le�m��-�)l�Zd��[���B��2\9WV"�k�m�t����P�>wU PIP_�kA2Q�y������%�5������D{�T���r�!U� ���75�>l�R��'->��ۂ���(3V0ź9����s�,�j
�����Z�uc�ۛ���KD���E����Pɶ���]�s�/�Fula��{� �m�<f�Ude�Xp��tu}{ٛ���i�w�Ǡb%,��Е��#�Fd��g�b�uu {
���\m�K�zT��`�>��I���jl��Y�c�Kp�?��˧[F��I�(
��C�{�^nv�D&�+B\�C�Ŝ�b�=��}!�}���ȹ#:�3�C���v�I�3)'G�=^E�6~�0��f�����K��l&���\���E|�7��C�)��~Q��9p�d��)8n�V8�gB=�v�|7�@@�&2mf��H@�_�叹���?���?���fC�n@X��,��Κ�;�h��Q�tALKX:KL]�9|_�*���I��ӞViSO\�n��>�9Y��f�i���.���>'>d�?�"M�6l�Y���+c�'�+��GGv"������4�X�{�4��++�ȼ�h�NW���{��Ε�;��b�~Q�����x�ہ�O�X~,��D!{�[���t����������>R&OB�C����+h���`�T���Qu��4t�i�~�H�1�w j��Y㞣�UP�R�����.����ӯ�:ʻWfu�/���3QQ4E�@��ى�uP���[���sI�V�_�dLCd�ʖq�&�0�e޵�]��3iD�2y��rHw��
����L�6>n�!g�_�{�P���#w��Le���*�S�r, 5TU��T�M�
'�;�N>��ӭ"O| � <<(8��\S�e�E�<8�=4Tg��㓸�iZ�".�,��GY�s�-ͳ<��{Q'��"�;ٌ�3\,���Oascۙ��-A�Q�M����+@��-��Է���ڌ�m^�ֻk75�\w�m�zĘ
|����,:����9/��.m�w�ȵ������V@ϛ?��Ao!�&T�g�)��FVT���,��,Ȋy�j���,�Ŭ�/bh�aXû��9(���Xjm��w���R����V�G\8�2"5���,�*��2M~��6�N��?/�~��y�+�Z��)�݂`T�榯Ғ��� p�m��V�f?�Z�q��������o����9���y�S$6�A9��m�x:��)������E0Vp�^p8��h�pɯ��/��^U���a�(�<?Rbd#c����?_e�zs�&�?>�J���38�'r9N�T?4��y� �ih����jV�M̭
��D�ז�/���'*�`϶�#��l7�y��@��_X���Yg_�.��o�D��|Y*uO���2�t�	X}� �Hd��HP�e��޿�gf"OF��tU�LF�<u
�-M�m�<��E�<w�7���Q NƦ�F�c� Z�*��@��x��A���m�,��+8E�XD�.T�H��-�"�)ji���`73,09j���|J���ϣ���+�i�IB 2��po�p�k�au*�1�ܱ"83ʀ���aU6��âc�<(��7��}��zA`�9鶔��vux�G���l��5�d��	;� {�� u�b�$G����<͚=�_���SMl9�����&1�A�xr}RYo�<P��~y�㪗��Q'�m����I���Q��x'յ���v�(��LV�ߟ�?�,�L�(�A7	J6���i{�M/�ZW�Z�J�Liz��q.�{��wzƁݣ��)?w�Cx��`��?c�{����0�"O`�3�wST:������^�ھ���u�������L��a�:<xp
�!ub7�W�,Fu������V>�f���uK!Up�'�Al�s��NF}O��1����#yn|�����)��r���q�C����ψ8�d�*KY͋�c�fQ3)�������W�_�s�D0 ������\Ys�K~l ����x���N}��(�����c��kI`@e�/@�C�LVC�11�z�ѧXucm�F(򮛿g&/�����Z�.�-�	�n$���nC�A22ՐEjUѢw����^I��҅���[��q���A�l�շ�WV"C�H`��xy �>�bP
�p�j1��C��*�qO��L���
��#k��z>FpAW��X��8eP���q��:�q(���޿.�,�5�o��(j�m�IT����Y��y��N@���I6#z�| 8/��
�ma���s�����q�ʭ�℔ �(es�W?�'�#ʍ����:_�Q�Q���'��N��K:%q뎮P��z1�*\��Kd�Xp��j�2�<3M/U����>B��F��/�Qx��]=��aC �i�|ٗgq�/�$���׷��eV�ynU'c��V�����Г`�qU�B�Y��{ἧ��I�t9�7(�WY��b��q֛u]������U�^Q��.����Ʒ]Z )�  R�?.���*�j�g8隹�d��i]�8���+�R+#�R��оeQ���P��q[�n�f�[�/�Q� ܜ0� �u/�oF*�4��`:ΠG0O#�D�=��^׷7{eY��)
d@Ih)������=a�Nh� ��:��RA���2&cF�;�aCTR\:��f�-󺌬wM_�n�����:m�jh}�@9 �-0 ߫1zh��GYĆ-~���,dU^�Ȓ��6"u�[p��咂�,��FkG1W�/'>�Y
)b���&f'�.3U�e�M�6ܕf����"������.+6�E�]U�<���.y�����QWB'��U���*�jEq��,�Vg����s�4����a�!Hj�P�J[*�g���t+�����\Y�����L�	�x��g����)-65qsH4�Ɋ��}�_�*SY׺L~��w�������g�$��B��a'd�ik8�+*��R�/�7��+[�����[Wɇ�<����#�3����_h3+���{P��a�/^��UiA-����x�+kn����Z������F�!�a����}�?���C�Y�����j`�\�M��݂ӕW��z�J��~<uPTRlʺ	B��MI`{)ޞĥiڶIn}�/3>S��_�̟�n}{5R�]�L`�_h�3@���/�T�*HH"�8LQ�y�Ynz����vo_���咷�8y�B|�[R_��#Z�W�=���� h���o �0�M����'WC��P�e��%��j�4�e����J��v�O��*�������<�L�\��L��q$���G�Z�{�<�`���"V�F�X4֠i��Z�ڧ�ZOb�@/�0U�5��+O�Q���U��r:^�;�b��~۽���_��>J7���,�u���I�tη=�Ϋ�.5Έ(i��E��������ǉ3]s��}(`�M��^��Ⱦ_��'����[�����L���KWN��Nu�T���Cz��h.����p�%��4S[Wqǣ� ��/6X5�,��6E�Q�D{�|��t���^A+k��I�:����<��t�LkӲ�/W�Ib����8Z���ib��4l~�l6b���=m��,�אo����E�X�F�fe� �R���հU�� �)�X��q�in�N��n�/���yx\f�?�S��y�-P�SY}��e�'��ۜ+�ANr� ��4��ĥ�˰:��ضT�.^�\� DY���`��<ŗY���t�Pq���C�9��x�i    �d0K�6ZVf������fˮY0��o�|>c}��_�n�Hqh�-ޭ>7?�ѱu�\B,q����Wi�WfP�L�4�yn�����ZO[���-W]�Yh\��WT�� ��������g��Uiqku4N�J<��L�����E�v��9�d��A�%�j�"�.����xm�2\]����l
���@(�
U�|R���ۿ(�e��P�J��|3@�!�Av����6�A��p7�!���^���P�t���RE�1��MM�['2
�v�����,�σ��Bƾ�s�m�,� V�E^?|-ܫ�}s�+��!3��em�w���#���i������� 󂡳�6��W�t�.M��'&�x�T�
WN�&"r�5��E��c'�BA	̢�{�,���z��(Qj|ݺ J>����}� �N��A�*nA�X����Z��D~��)���ǘ@����E^�&b��f����dA��J�P_$[�:�n�4���M ~�(|;|��C���na��WPl�}��^���c3�,j��J�]W��p��,mj���"a-��͉V�0|�Q��	1�.\Fr�d��6���͛̦��<<��}Y/�CԾ����A� ��� C*���GjC��$"r�����ف8�/�&F��.[�t�4�J/�u��C�п���(����r�����e�2�l�sxA�6i�����w�q���$��iM�AڴɌR��@eh��Y�(����`{>���L�ձ	��3W����-�ɋJ������	��'@���n�wߠR�}����\�i�r�2Fnh�QP+5�����N,���:3�jݗ�X��6��<�H|	�t@vK����aH�?=��<@�R��*�0P�.��H_�ǭ�E�.��,`�&���G$L��4��ld��h��T��[np��C���0�����KҪ����V���f�z��T^��/6��*(�Qɻ�.εmk_u�Jx�ɵuyBaUu��	�A�>�y��FȲA=��v^{}$'�n�F��\���G,_�\u/	��\�Z+�M�ln߶�gШ8��i�H=PzQ�(�*�6B������ѿ��kU�=�{�b4;�Ѓ�,����4��G�����z>ئi�vr�L��{Q��V;D̑� 3���h!gK(��a���B�E�Ɋ��}�c�4�=���/�� ߪ���O��`f#��1n�@���/����#�
P��o���N�iS[���K48z����=��ǭN�J���M�kޭ~9��B)ы/`(H�n��?gq�li�W�ДU�`-m��PS����#������`��� �1�H��4|����ZVI*��Ԋ��F�ȎǶ	"�o�����=��V�1�Z�)eUA�?r�*�gP6�0�R8�<��MX�gL�$W};���2L�B�iB:>_�G��_F�'N7��F�����`.��m�k������X�h�c���`ofcЁ��� z��u��)y�'d�Ml�,�}E�3?�����n�_��`�ϴ9�j_�WSm��)[�����M�	ݕ�,h@�ѝ� �Gq3z���{a�d[W�+lhL�Y0���~Vh����;�E҆to�n�J��u��`ſ���l�ʫ��n����}��4�K��s�}P�y<����+�;�$�E���#>^�f�|�RFX,�ͦq�U�5Y�%�ow��,A�&�六���'�KH�2 �z���T��a�Lċ��5���e�G��J�6k���L+i����L�2ģ����H��.��������_�wF�ils{�k]V���M�����R���k4���u���w{ }g�90H%���?�4��=�u����֤5}�/���T��lZ&_�	���t*To�# X�MM��"�	X �}@���M A�Aq�:����5>����UY����+�~AfqYj���V�WN@aAܐ4�_�"�B�7�#�N�_���VA���n�0�o��=T�S]S�m=;�.u9f6Qebm�����w�.Om8�u�3�]G���X�[��R���-�ABR���xe.��W>��ݺh������I>b]+�8������ˠ,��rb/N�_�
�ɟ��-wYl��h}��[� l%|2$l6Q� �wj������࠽�4�Y�
�ȶ$�@�z]�W���#��Q�t���ٚ}�GQ!�����K�WOG��)#0��6�^��L�E��k��8����^�&d�k�|(6b0W����%!�U����`���X�&/��r.�c����9/��+�-Aj�G��,*�-rw+��M�6v���K(��,O~+��#m�E���b2�H����сx��� ��2$j�ch�2Z:�'��|v�s�{!g0���`�m�n���=.���ˊ�7F��>7A� >l)[v�$�(Gr;���dm��5�`)�vw��f��9Wz���7�!����O��pD�0P0/�9���J�>�D���p�ʐ� ;��ŵ����\��L�u�b���浔Y5�V�Sp|@U�wI��"e!h���F��o�֔����*$Bu�Z����$��H�XVD�鳤P������� �扑5|����<+o�$�a�K+#a��d�q�S�7�n�i�K��\W���xV�~�G����,�yQWud|r,����l��֢(++�B�E���Elu���0
�:H�����D�p�妯\ϲ�DU�f.�PPtD�U�[�������Z`h̢T�(E6	�Ʒn����Q��B�m��9�!&�k���{��S�	u�x��T�B�@��*�i>˰i�U6�`�6�lMWߌ(���0�y�l��V��NLe/bK}�uJ8�bTg8�Qȣ�{ZWW���NX'6ϓ7X?�(�	��X��\7��0��4Ɫ��Eՠ��ė\\\)�=�T���0���� ye����V�T'�^�J7Bߌ�է`|�!��?�S��V�b��?cpڀ~+����� ��B\�A�XA���\U�B�ó��/��\!�U���տ�W�/��bw���aX4s�*� �c�|�1` `<w�@��֎���n�2v��Ы�/�$��&��`ܾHm���l�*���_o�T��N�����hE�n������ݢ��������|W�\�Ry(�ymF nL=�hù�g��S>�ΧK�b�2������w��ب��0�x���E �JU)�=g!ti]���[5��u��^+g)4�%�U�^�x!�"���i�G����E�;��U}i�O╥iVD^�D���}Yln?rY�W2��k���1�Vv�ۮ����`Ȇ�8�[2 �'�|���}m?�MnORg{:��"�C����I���^ ��P�Z/���Xg��R3z[��U�_3������Y�r��gqg�UC��U��eY���>�6��d� 1Y��L{=q�>)�е�hpQ���Zy�m��)\��=�f�T�R5w�'�<��|)4Q��.�3ˢ����h��ֱ6ц�>A�ق�W:�g�H�/0X����B����V�Ϙ����Md��h��v�]p�*߰�>�Ȓ�{t��S�q�j`Ӿ������ $Y��󃦎hV�π2���(�KY�id}�[��K�Xå�ͺ�άv�Ճ�[:V����>� �<S�g�ʙ<u=^46?;Tr4l s@�C*p�R��f�Ϟ�+���8�.�^�
]��:d�a��Eo�� �����k��9���[3 �}y/H�9��@�.2!9{t�ΝYP�YW�V�-����2,͠F���B�K?���.�,���{�F���?+<���^B������<��?	�@2�qD��}�C�`[�O4z85�c����U@��7���U�p{�?��kT �Q��laF�;ّ~;�!LX�!�Ꮓw�~f/��� �l"������7n�E�$�C9K����Q�0��6��$/�֭8s��Q�������pZ�]�Ɠ�ٴ�f���q`����_��������?�T�"WrZ8� �CsO?,rZ�ے����K'�@P    -�k
�t:�Y�����%�³띴6;"T�N� �G *ǯf6�}7"�������z{�Fi��4�!�8�]��8][r�����1�u�(�'��Q}(�,ܭ�B�R`a+�'}u�EEmk}\E�"* I����$l�V�}Ճ�Q�<�w�_0v��JC���v��g��!�Z�+ud�teQ�>��S�R��u2���#�-��%�
��Y�A��À<7Sx��S[�2�{���o���z*��T�4ma��> �{�gj�Fe����90�1�e{���C�d4M�4x��'6J�}�o҈�3[Q
!"�!C��e^ߊ��;�튨,9�Gdƣ�V��Ce�Uv�>��6AYfR���+m���2��k\@XJ��M~�N�v�L�J�J62I�� sՃ*ܞ�{i��PrByeyV%�8$�~σ;�y��T6�Fb��^���� 
�"�G ;�SɰaY�S�b|F�yՂ{�U3W�p�Im��QRك�D����d%�>snѠtR��W��s =c! ���>+N�nڹ�����(��3hRK��:�͹�����h��]�i���Hy���Q����&Z_�j;I�*]�?�K�k�}����{dF� �o��[_�k�1͔'�y��VY\@N<*kW�ic��9�U�e�	%%�ZiH^��kn�b�������n��K�A���Q��%0^���{)�����x�YT*���S�/�+Zɟ�G9t�d�Q��O47ʚ��u�sa��7¦G�k$��J��x���	CNaqȻ���?� ��0W���&*��q�� �i���-[m�<��r�OG�Z�ڈ�hP:yz3�+ƕj�v�V5+��J����)l0eP���̿���;cֳo��!�}��O'%]�7^�b9XګԵ��<|�5�rez�j[�6��߯�:�f�����S��4���"yO��:�}X���C�DїOꋋ�2���[j�Mq����u���si�˕���ta�$�i���o/>�h�y�����1��8.
o		��A�xkMkmd��x��M�������e&}mY%ov2���iK���nlV���Av1�����ml�/J��"ya�:�	�,z&���^p�A'�Ǌe��*4ب���ݍ�#^�د�����h�"&H�NC\����W�������!v6�b���a���"�d)y��	c���oY�+��m��~���]�C��&K^a���`��1�,?iaK�:����'�s�0�,q�i�����7����� �H��T�z�
�0�=�qy�Z�UJ[�]�>���Z��0p����Ӹ����z̪4��8_	�Ƿ��ߺ���7}��	�(:��T�1>n���З}�/S�@�S�����x7�������.�Vc��v��x�. �4f�L^�ECG<W��
��V[#s��wLx~�!
������6 �ִ���łv�l2c���o.2��F�6u�@����ۛ�2׵U����R�^0E��Qѐ��~l�=Q��k;J�O�U 0���(��_�n]�ݭ~���M��K��� �h�a'#)ND����p��6�[��5�
8�;�V��8.��.�w���_Ԯl���>-��L�*¤�u��E��(y��̤��܉�����ax*r��ӺR����I�^��q퀱VA����w!"���i�O3�ۊ5��#��ۺ��^�Z9�e�3���Q����&������
��j��4�y�@�~�"����~ak#񶪒Ϗװ*g?�QH~F _�Vea=L~��q�Άr��ԙ�JF�0M�. =P?��N>�Ō�à>~�q��P����`�mR�A|��S)@ҳ�
lQ{��YǙ���������F����`	b�0BiJ�����񅒼�1�
�T�&?ӯ���=˖i�LY��7�9P��U���4��u�1�}�X������)칈nRT�����$�+�����淟�2K3��t��J}���@����alss?������D�T�i�z�!�*�<վ����)�$ar��Z>�����‾�u;���i����S��;�B�Ղ�L�YH�Җ�Q���m����2�r+�gZ>&�;nI�'�c+.(����Wh��щI�WB���4B�{j�(�d����S��TPܞ���|�����8zr���`��w�cG�n�~;Ю��֡a:~Y0)��W����'|[��P[��&Y@�0���`l�y���/���*D;��B�\��jD�O�7�H�w�W,N��n�p���@Be����x�:�!��R�����P�SN�г�����=��po��]pbk#.M�Γ����`t|܄���%�1T0W̅�ޠ�
| e����g�أ�q8�@�>=���|��M	"V��g=
D\�0p<�0����r=��j7"��:_�"���
�J�h=��~6ha��Y�@ȇ*ϝ�y�tWO�-��'���]h�a���S�L1���G���?8;�f`T��C
�wp������VHv4�]������u�R��4�����3]U�E^��F,"���������C �b���a��6/�"mYd����5��}�/y��)�ưL����Np��e�ڠ��� 6��n��nhJ���<buMw����m�<3vAq�7�7�U��iO8F���ڼIg<S��EP���VX��:lZ4��o_Ve�d�N���os�":�<L��X�#5h3��V�]8�g�eU�e�9L4�k��v�^p��4w6���I.A�U�-�3lM	bd%&�U��~O����Jޏ���zQ��S��G�h�1���Q�ǔ��Z�Êת��ZW&�H3�-����h�\�+e��]�F+���<�j	�$��L�dغ�62�3���uY.@$�&+J�K�	xg�B�.cR��r��~�tъF�=�m���\.��y�-�Бg�4iUD���E/�(K�`[�کb�I���"@5�Ѐ������cw>��F{��Pc8�C�N+B�}=}���͉o�"�C��˶gN�a9Ȗ�>�?D�݊&�R �kP,*�f���F�C����:H�`�y��k��g�N��0J��xE+��`4@�U/�Cln�.� 2A�K��I�#�\�|�V�e�`�'����ZX4a�;|j���.}������:K�ש��Os����澨�Ӝ%�Eړ����Z��p ��<{u%N@�)2�ͪ,�(.�[j[W,���C�0&O���Q�?��^�a�ǩ�<2&-�
�GS��s�f��҇SΦH�+�S�D+��{�����r�ٸ(�X�H�6fc�,�2�7˷hg��(��L���	D4��=�s	���a/��ŭ�b�'�t]�n�i�*_���T��Y �}��F#((>0M���N5"L�)��uC[_�b���*`�T�tt?������J�D����n6m�&���VYZ)_��ɛ�v���F�]ߣ��� �E"ǽ��+��|��	D���;����U�9�0�6�@SnA$�4��m���2yGz�fx��cV��78`� ���g��*���؀���Xu����ʳ*$M���׈���r��\������j�����{�J�ĀͲh���xc��"�ٴk7D���15 ���H���"�Jre��C�ʰ�ao����è�8�?7A�N�D��=QH|�d)�6�Q�GG!�	����؇o���.�����Ăw!��Vo�]ʕe ��y�Є�^�`��]r%��,����s\��1��T;�nF�k"q�b�37��8_��2�=N"� 7���.�<=l�h��V}����˚Z��^���[���u�m�7�|HU�k���v�Y>p+Hb��!��J��A����y$zs7(]v����uB�m��n����
��L���]�ݯ��b�&��"SKCA��}�e�8��H��+�jBt �T�Z�S%�nYSі0b�mԟe�z��*ˬ�	���ѐ!�`[���C����[�Dk볼p$Q+�!�RL�"y���A�(�V�)    p��Š���0���"3E��F��gE��k��L�62�L�������ݑ�0[-%Fu��&"�Pė\��f���{U���
>��e����_e�-$��D3���o��v�����}Qړ�>
X"ɤ#��Q'��R�P	�s�C�z>�m���S�����.������d�ߏ�v��Cʃ:�E�v���ys�ދ�l�.����Ek(�� �
aΞ�@I��^����*�:��6+��RUW������Uƚ�a���Y�����|�c��جj���p��ix��d*LA����.M�ؤb���|;|`�� �SLH���hq��g�a9��b��f�5yZ��S��fuW,��^�T�5���[��q��&��n��G�a� ǰ����r�ݎ���Bg����͂�����p�����l��b;�r�*��i�P�ݭ�9�@\1����JyFkRk_)>#s��.��\��%e��FyJr�?Jq|9g�p%�|��S�`YS7��9@���h�4��կ�hNG�a}��h�//�Ou�W��xc�l��vAt���N��D��I�HO`�VD�<(����>P���M��(�J��T3���Q�,�YZבj�g������h�c['1͓�h՟T
��'"H/]�p8��,��)�,P�)�1(�at5���� �j���;�E�j9�
]	�My2^�ܺ>A�@aV@P��\�O����b^3_�֐�z��e6O��Z�2������g������.'��&ǯ�#��2-mdk�h��<k�*5���\U�+��5P��;\�K�gqeF�9xȪ@���lw�A����"��/k��E��?��Y(�4��W��f��E�,(��:+��V'�9�m�7� [,iش��I���7r�39��Cy�e���ap80���Ո`X#���<`_窸 �x���l6Ղ�j�H"�5��f�bړ��:���^�����$�뎌m?m��=����q7A���m^�͂�zmӀ4q6y���H+�σ�!ӎ��D�g1j���ˈO0���Α�,���ᑝ�bQgln�1��u���΃�Y����Y��?Ŵl��PQ��}9r䇃y�2�D���k���^�����N��[�<��telc��;��o����K#�׬*m�z�hnU�A%����/�)M䁋*/��������cs�]/��֮R�
���shBaE�ڂƌJXF4��0#���h[�S����� �;���vz�\Y�Ȯ ���m�ʴ��lR_���,�u��c,���Y��8��f%Ö��$�R���@����H%q�sxU��b����2�˛�K�!�\a$������s ��Z�z�=W�ܾ��To���m���N��?EZG~梑��f�.�5�,�D�ʥE���#/6,�.,�ϒ���9�g=�,XYZ�];��%ls�%��+q�vi�L�a�vW��:�<V���ɣ����^�)x;PL��(�fZyk�5���T�4]Z�`���hS"�
���1�L�����uP��Wo�=%���%� ���ZQf��ʚfA M)M�K��:��S�+��oD,�P�}w&��Y���V�e�"�0��;�\�"7��V���W r���e�nlw: �w�v3'���������#(��ԃ�w_�޷��f�J�f�O�ç3u�dh���ض=�df��'Q2 �f�H�ǿ�僁��F}�"�&/�3�h���o��)��:ds;�����'�����B����{�qS$Z1t!�F˧�4��l,�]�n���+�Z�_���@Y�|m:2�@��J��-�R:*�鴰�|�k>�_1�`��Ӗ���;:���˸��xs�"��.��2�(ĸ,C-���A���9�Dn�/�����W���i�*y�Un�F�*�M�/���o�5Xy�AE�i�ɑ	��A_���[�W����2Χ�X6 q�f�Ŭ�+W==޼�(�v�t��]�$+�/���O1��$���ҋݭ>v��6a�(�2�,�dR��2-J�dN��I�T&"�
Eᓆ�O%�z��Q�B�q���n�ǫz$g�x�7��l\��x�^Q�o�&̾��U�"����x�"���}�Lۗ �s8�Ta
�=�g&�8hOT��X5IQWu���b�$\u�����3��4@悲�a�J��x҂���:$���4~�*�q���.�ɻF8��u�I>�H�遌�аʈ9�A�t�6���L�gȎ͂�� �J�]�����Φ�A�� �X��?ȴR�v8���Cd���IAſ ?���,�<AqU�qm� �hSWh�pɿ�W�1�,R����X���U�v��t3�WG��uQ-�#l��W�:�i��n]2�{����E&I��[�6�t��Ky�z�w�e?��yf
=�qfD3 bҍ�I@�����>�H��gɛ��x:tD3^D�G,��.ks�~�	���&+#�2\��(����ls�J2ݵty��Y]�Q^P��A@�a3<ɡY���Фlт����gX��ig��h�ۣ��h��ݣ��?:I��N��&c�)]P����l6�t���6������V A�%P�譮���ջ�+�ȅ�%&��) �/�|�oܟ�=ԊH� "�"%�@���J�,�"jHڅ���T��;Xx�ב����2	����2�4}�􏞿��������\�N����w;pcf'���"���zݸ6���못�aK� �A.�O,�G�xE���Sdg���볒w&�
"��Q�=�¦�A�:����vDu�G+W�����f�'V�mW�޶���:��o���A�ර�W��-���|�`�2s�+U)����u�f��ͫ�r�}��Uc�����-���	�Wس� a��_~��8�?�i\�e<Y��L�vA M�J=c5����&�ѭ����-���}p��<��r�1˙ݖU�շ���7U�$��A�/�}��J�A=�n�dF���������y���7A:�c��*p����f^[�"�en�1Q�e�w��o �{�+��(N�>�G(������DLj���4J�4yd�s��Bi�|�"��V�!�]��$��[��c�i�?j��{�տ^��`N�������@��2�ټ`�4�M~d:[$�2[����Q��E�Z�?� ���o�ħXH���jܱ��Uz!Mk�5gO݌,<��q�{��3�l�����N4�]�;?m�O���<X>Q4�|��������R�ɝE��5F��$��1h.�<��5gih�;"�NםH}BP������=��t��>�v	���y��t�յJ�(�qB)�j�ܰ+�W��pxf�C� ��eA]����w^�Y!��ZWJ�'�����Z{���8��n6�wYUEV���eP�}ÿ���U�ɰ��e2�dP���j/��$��O�@TI��XLF�������3�)��l�n���+�:ׇ�H ��z�{����ز�T<�x�A�Ώ4�./N|0�Q���V��������Îs���Ydw�x�eӷ�目R��E�|D�c��
��}���+:����<���nVh�2��k]�]o�%A3�РU���js6�Pe��f�?4RR;�����w��E���7�.�M��S誢��*׉x9v#��ׇk�a$��|e����iv�����w�z���J��fI�\���I�Ð��]�9�
7��~U�-O�X�M��r���R܉_4�[�uf}���զ��+`��� -,�x�|&k;1�����Ϋ����4U�UUev����:���%ׅ��=����#Ȗ�����X��QkH%�L6�4Y�V�5O+Jm~�O���:aj�c)%IfP��UR��J6*�>T�ŲSFB��oS4'��T�3����C��q�
?dPG���Il���@_��_,5ҁ����H.���q�P2�1���9cN�.�T(x>�N�Ū����
1�z� �/�aH�� "'��V<q��*ԙ��yܙV4�xU�b�����W<�e��?Xv%b.���-�wvo�P�T�1MA�(�{<�P4�U�    ��a��<�I��ⶽґaU�E���te���k�$Y�~Ƞѱ��b'u��t��=�]gZ�<\�c��5��MYu8�sjLkn��K�Rm]����)x�}�&�_�;nIpNq�O��Z#Z�I�\��H�ε�	6W�K�B�C��+
�M��\�Ȗ�E�Vǻ�W�����Hs�����-ˢ�����U�7]z{���d��׶�I�ɾ�!O[�3��'k{�h	�j4g�rf�ԝ��s�B��4�Npi��D�G<��xԶZכ͂s�;gd`SV�'�I�{?@���{,�葔�0��ؚ���!�4L�v�ߌ���)l���N��΅v�k�H�
��p��H9S:�>�����#��ZrBp��4vE�8ŏ87����6}޵�Ǯ��J�ߩ�LK�����^��9p�᧰�\_p.��1J9m1a�ŭ�2������vx>nU�-�M�>����1<%��WoeP��R|���è ����|����U0
A�kJ��*�<�Yz4�B���v�����ɐ���?��a+�P���_�NR;5Z~�\x��g�qP7a_�}�z�h���Y8뢈���+�s�;R�)|�pV����	.�_��e#�>y�"0�őFE��;=�9�������U��^�i����7���0�<uR�TYB���
1�P�
�2���H8�cr?Wt)���+Uf��&[w��gF��vU���U�����(�,8jB9>x,֓�T�㥨cM��NA�M7旝�����on�����:�,�k��UR�*�a�J9��U{��;a��-�J`I�ƾb�gvs������-j�� kc���䜁i*EMEG����q�Q#"��y XM� N���ٜ"v�i�=�W�_SY�%ZkQ�{3E��˗g����"z���`�Bl��D��#XK�s�<�g�F���fm�Q��v��ޅey��������wr~�����LɈ�f8��'o������E�E�^��hu��܂+��\��I>�&����۳�yR��D ؼSbv�� �!4/�����q�*�V����:2�V�@W쾞�����Vu������/R��gJ��Qkt�C����(��6G�D��"�����yƦã����z�Lњl����A�d'4�v����{R(u�!	���3Q/�6M�;��(��y�y���G���D��k�.9�E��^��l"�i=���'�suO�Ih����i`�2�u\u�hB�u����}BV�Y��qɯ��b�u�y;8!��ފ��!\�9P���<�
����4�>�d�e�M��������թ��IE�Qx�v���B�O�����!�_�y�����S��pY��	qF���dⱭ�k����<8ge]��{�Z�uW�Y�;��vuF+��x��Y#��w���1,��U��]���w����r��Br�OC�!is��_���zRX���Ϗ�K���1
��N�\u��>�ki<�#��.�Y�z챡�C��O,P�����E�S��Dv󍆏����`}�� +JȊ�+In(^d �?��L�|F~�9m<p�G���ˁ�Q�R�,�u���ZК��K��_o={%u�`)C�q���Q���K�L�4�8�50��ϕ��8�ovO��Y�5_6�e�5Ԧ,>��� >��1p2�VJ�C��I%*_ӊ��/xfF|�܎qX��� ��+|�𬺢u�	�٠���L�0�}�_^�Q��yʋ��������4?ѿ�8��ݏߩ����I/#�J p��(1���n54CB�p�0�@L`vs�_xmŇ3"�;���ɚ<�}V��*U�X]%������ �y���rT�~U-u�i��G�����nN48�g�KP��eӋ�1�1nA\mZ
^�������t/@�~��c���S�������<r�m�g���t�UY�3	�j��� �b[����NX6�_�O�<��8���,H�;�+��Eg��5�����6y�gí0-+o�M���\������\s�=,I��M�#�������Q���e�I��@
�}���󁵏S�n��{_���2�FQV ���'S�E����px�B[�<�	Zt�o��Uh(��%�3eJ�난��F���� �&*>��p�w�M�Ppk���b)��0q�ӆ�	�����oQ8��jp�<]�;� XˀE%�& �>�S @�3Q�������l��"2�6+���l�`יL�t5�Ҿw����u"�����X���E����¼L���ہ��*%��4as����ҍR��q?�2[�E����i��uT|�
|�_�l��i���:��	��LݴY� �6�4��ڏ�:I(���2l��G�찍'�*R1,�H�PN0̀������9����0�h2���,8��$�y�HqᏱ�3R>�>[�^QX����,��_��w�c:��k�4�!��u��9�Vy_.��zdUo�����c�B�4�S��@L�<(6M#3>�Ղ.w���d��F���L��������z��DA~�a�	Ԓ�ɈD�n�C_x�h(J��+���YT�
_D ]4;D�*W��yh��7z:��̀��A�L}���B�
�)���l�>Icκ/�iߢԇ��?�a+�!3�Z���x�- =ʱ��OԱ�sN�Ǳ�>�{s��X<&n/�-��W�+����ͬ��FJ��A
�����Ѻ��j*���;���H���L���fm�n�q)a�*�N���!����yϚ�|�G���S|&R ���$�g/�}�B|�<�n�Õ��Dbh�?*r#6
N�yi��˼���]�^N��Gl���s�Z�Z�S��Y�KSq]F"v]�W�i�z��M>_I���+��0.��b�Br�"��JW�pb�d�%���I��\U��F��M���6�}��׺n6.Q���l�U]�����U�]����+_�D ��5WmR@EbnN�Yج,��{�/�%��4���KM�K����/��	RCK]��}7���"�vr4!�ۮY�ں�5^Y���l:Λ�g�p�U����0VlF��}��> ������VYW ����v^:ߋ˚ɷ�ﮏ�̍�y`d1�@������܏����<�8p�mEOe�G�n��v'����P�At1�!v`�ƭ�����[�o?�EZG�x�B�!Q�였�3X1�� T�#�	���N?�T���E��m�����"�]x�v>�K�W폼�[�Z<K���M裕��>�'*�ݴ��*��[dOR�z`���!9u۰����tR2^���#�$fA�Ӣ4�T@�:���D�j�:�#(F&,����t�?4�R�s�57�b^5�1s��c�h�"�4U�-�����eM�FZ〒4�CO�@�:_��/�"G%�Į���}�P�65�����^�T�%�xu���<p>^(}���e��LLzG��M���)ly���߈��,d)��\�0X��d	+�h�d��SR��(�Y�F�?�,����$sn��Jym�k;��-��u����K��
�fN����!Ecfa����W*�g�n�/��ߛ�%K�> nFc��I��)O�뮉j�.�Y|Ln���V��B.k�b�5�Em*�� ��w�H�^����\�0��5������_aWT���6Y��)]���pvE�KC$��T���� ���i���2|�d���,h��b�8DC��ҕ��%W�NH�+�C�N��VN���u���Po���f?����p��[�/��]&��� Ω�,��������Ͼ#Xwu�������MܪRh  ���P�v�f'�Z:�"����C��Ӊ9�9�J�[a8�6�E�F��ίh�)��+����htK2����=p�������������nqz4K�i�U�"��[2v+3h��Ѭ���4� I}�5Ϙ$5��M�%�W_��
��P�k��c�N1f!bO��:c��o�B�e6����6v>����}���
N3�4ː��    �~:�:��Jn�������U�/P:e��*�ήk{{�_�U�-'�Ҡ�u[snOUz\� ��F�_X��eK������y֭�EZ��AN��\��ಥ�$|6y���%¶�⒂�[i�RV�o:����t�lھ����.�U�nm��^-���Rv�Or`��xhH1<���#7���A�x��,j����6��,�\�u��u`Y��ml��|9�=k�Wɨ�4���<(�$��A7�N*��g�if��2�:)���r]�/����u2����A��O<�:���I��Y��0��p����Z�+kS�E\�h�L�w����+�/�3]��ّ�Lr:#*;�N�Jx�_R����p��a������ǧ�䵄�uScb���;��vՂ�b��4�E�0���!бNGJ�R��j}��i׷�-#v�ޮT��[�e���lR.V��ō����+�X6y�^0�/���)�C\&S����
��bck��q���8�K���v���&7E�D� lD�����g��hI�)�v�R�*�Ш��c���\72We!������ud��m�(�e�� DR�-����߇�sP�F�2��;��lfo%VYU����W�+]��a%G�D���ܗ-�qdY>�_��bu�x�*iZ���he���X�,ff�s!����s��X(��3�05ͪY p���v/�	/��k�3{��zv�=],ɓ<,�"��6�v�1t5��)���q<1��R���[�/@�R�����7�TCwt]�E��N]D4Mlx��i���b.�H]���[�ۺ�	�q�諤W�ר)O��Qtv.-!����iD�r0&�h�z�/(^�Өh��6ҽ�|7et���0P6��)�`��\�UOs��g�0!T�Оx(�D�-:��5�mp|������tq�X�B�V2�'�e=�����\2v�KI� eod"�9��Զ��P����;Q����%����[̲(��C��e��ۛ�"3f�8U�̹���\D�s�;
�#7Ff������*���/��������`��	#V�d�gD�Poi+�*�E����i��������HX]�Eڏ�W������`
>8��*�Χ9ʚ�@�U���ly�!��h�%�!�p߃�$�Ҕ҈˖F�Or��#p�E0@�t%��i���i��L���q͊<�{_0ɷ�j�ۛ"Ϭ/;��5t�:M|R�%�+~ GHO�z(|�>��������=�jŴ�{3]^�n�U��Ѿ[��-� 3���[s;q�(�DT�D?�gv/�T�D���QSj��v-�K"G�����`|	�!�TL3�u� ��4�t�&lLl���P�Eb4���~r�գ���{��8�v�7Yx]J%>�4$�8S_�F�&�j{Mz.Ck35���0�Ⱥ͓��ξ0��>�����d�5�^?N�ae��H�L^��t.R��Q�u�IX��';T���y�S���#P����nţj��5��؍�s��mO���b`8�\��b���%�s'p2�Y�7��I�GK�EH��B����q�b+Y��V�<����]D�CTH�y��>�<L^E+QL�X�˾����YZ����P��mܗ�γr��﷡|��<T䫒�d�t��|���N� ����	_S�I^įJ!4�����&]֯�ʕq���F���q*�kL���s���b5WH���	����/$[<�rN��ZDԵH60�,\D�ά�8&v������ceDZ���ʺ�NU��p�Lߎ/hIDt��0$%Qv;'UV�36c�uيͤ�����*z�:aExF�G]xV	E� �ټ_�j������{�����>MP�)XƳ�L�o;���6�Rs��h�<�s�4)O����.ۺ������
H��Ո��vH��%y	�����-��
Eu�&���&�{�t���H?.����Y!F�Õ;��Q�S�;���4|�i���4.�={����i�4^����4�aj�E�CI�d�-�r����7E	�Hf��^LjShC���calm���4��E[��4������K&�B���I�L��N��F�,/ܽ�S�'�7�`���rۯ`ʛ<�*�<�( ξ��aWG?m��w�k��"A��0��||��w���'N9�>wݨ��M�b�!��kk��P+�mg+裮�3I��h
��B�O[��S���G.l*�����3
����X�,��R4�pi[��5�vLa�ϥ�>m�r�:t���jl���7!�."��W`{�`� �m+2�+MJ�;RL!o���Θ}Ղm�(�*��������C�)@�M�tETl�s����F��9�X�׊�i�(��:�^��$hB�+j�VfE�ol��ƫ���r�e��D�H��T*Y���;Zm��t�����<�˺+W��a="��*�mKƠ}l0D���4��*1Z�,��p�N�9:�C/���&����䡨��.�.�a�K��*)0�	:�e��Y����V�Q�w�<z����y�	���p3�O;6ԯ���+_0����1P[�p%nWf�i˪�7/s-�0��dk+����<+�H�v[�
:�B|�x���H,8@&�_A�a���}~<)���ր�~�猶�=@tе�$���{���,�P{Z��ouTI�4�;�A-���<�0��.�	�V���Ub�+D�� ����f�)n�U^Ӭ E��;����$V!��&� ���9H��p'�녱����9%tۛ*^Q�����%�"��"K�o�7YȻc������e��⾜������W�-��I)G��[���(kÚﴍ�A���y�F�>�g4�)�r8'ɾ�kE�T6�~����^<t�dF��2jUn���D�t� �a��}�������J�E����Nӑ�L	�� ��p����%�4I��(�\�'>i��'���[��c�H�9�l�	�#Ph�ҝ��C���NK5�ym'�s���M��V�ܹ�J-�"���Gy�i0p�B): u����,s��x���< =��$ �l�a������J�>��I���.�&z7{�aAV�7�j�δM?��8X���`s�&7�
�^���~���˃�o�w.r��̝Z���t7��{�j���V�Ե���"����Q�$��`Sd�]�4-��_JB����(����H`����"B�kl㰐�`������Z6-S�����~u9�(�^�{,�����㷥�����H�^��fE�=D�=����(�eƣ�q� X��%6w��"Ŗ��;{PrF����
d�X��R�9Jȧ-������+bW%ܗ'�G��j�O���J��g�;�T���x֦�Wڨ/bj�I}�qF'%�W��u'?;H�.Ք��Z�<�=-O�_��Z�A�;�\`a����ݥyXj+�<+��3�psMU��2/��B�LyQ�\D�x/�Ɵw�M��G�t��;�n��PRi��qC�����sok��V��½@Z��yt�'1GU��I�=��ʨ~?���,��2�m�4/�8���z�4S_����@���B��b>q�v=��aH����C����r�dF�f1\Ϥ�CN�MV g�.��"bJ�;�!'�<�9�a�>�7���Z�A'i�l°�'��j�sA��l�ށ]w�qHƩ����.��C抝lM�`\��~^D�K8'8{:���sX�����Y��Y�q8\����dŋ�U�O�����(��o�b�&c"v�j*L�q#�e�܅/�.q��/�<�ͶmW���^��u:���WU� �MS�M���~V���nR�kq�������v��FKmU��OZk�:"/�x�	�~&������QmpW�h��a3+���v(SV�Ů��7��@��)�UEQ6���_jǲ_TQ�"?�s׀�3p'�*��c/�=��x�h�����CW(�������9Y��#zz��/��<a�Ez���!G������E˄S���~0�Ig�
"����d��VE]w�.�QgM�b��L�)����    k�*+�r�H��6��
��ҵ�?ci���4�]-=10;_v�����?2��{؊t=����/�n����e]F����u�@���}��^vb\�u:K~�^t���VH�?w��r?pC{��������7��D�g���]�o���Y��IO�<>B%��]����X�	���(h��d���ei#�6?
YG7�5�M�����[{n>`S�!9�1�;�bZ���N���Z�p�	, J ��ⴾ�*�I�
��"��p�O�U��ںd
L� �C��EF�Z7�W6�u�"�I����Z�CW����U`�VÅkS�+�.�Q��.���{A1�L�K��O��҄,E�Zn�7-L��i)WT�ip��pa5I�ܞ��,Ob�����p
B����B�.W���di��/����f���<�R�M�cI��qo�;)`�,����,���VI֭�qEnS4l���j��t~�$�'ŏ^v^Uو���i��3�;@u���7W�q������D�/�˕c�k�CG]D�ntr5���ل��"n&��D��K0\p۔y����&�<��������z�k���q�բ��:8���Qs-/��<r67e`��p��Kl�Ⲗ�(�ę8�V��y�n�x��^q��6�`n�?��6���\w����B�Ry�2�ʰy0����~���k[M��N�:Gs>�6�� ��.#��/uP@|+(%b�]EN"׷��"�U~��d�wIZ���Ul��*�4����[�>�Z��	�|h��Y1k^��Ci�?��_���3��3�ɗiۘ$�BB��X�e��z���Ub�޿2�[�6-�\O93����sP���M�P��Z�tŶ]�We�ƺ�7E$���
"OÉ.`�3���K�89�������@]PūW`ꢋ�+<B��m:}���+����`��I���;Z �lO���buHI�s���չ�G`�T��z��W�����z��G�J<� BSB����T�����E�N��(��3���w`��$x���]�2�w\��D��[:p�0���>������E_�녤v�a,.uV��		�^\�+����3"���Z�p��B;��ȸX�?�������ʋ���דve�oWpK
c�h��:D&	|J���I��B��ӂ�6t���x�/'�"��"fE�fY`}�P�0]]+�^�|�~KaJ�=�U��0^�#Y:����8����rA]��+�ȥx�����m�$�<*w��/S\�]j��C�F:��P����0	�G߫쫻�ኝ�{ �n1��H� ʦkM�B�ĵO�gH�8z-������mp���":e���%�E��B���~�j����?t�d�L4��==<-���j-<dӢ���8+���"7��q�lS*LHT�Q1@Z~�Q�����vʼ΍�]}�9R0��>�o�#!LIR�9�͸�?���;�/Bâ���ԫͯ�|5�T���4}���|����G����f	o���_��EK�&T<�;
!���z�..a�,��nT+�<SxB�x1�b�ơ�a��;+�/`QD�q��~��G��wP�4��i�i["�S�f�?H�zuT��)��e=����
��>�Z�_7��OkAb�9�ڋP���B�.P�V>t�G񰬝�	�!qQ�x[��ij���3m3�y�V@]���ٷy|��?�u��{�^���NҞ������3y��SK/}�B�ű�y���Q4�#Knh"S����d���5�By�J�{�z��#rN���W�6;��gm��H9���l��U���"3g�����J��A�P��4i��jo����5���Q,#i��_�bB�o���	U������&��0��/j�D�;z���*��=ͲԄv�	���E�����i�A�ֵc��71m��Dt�<s{oY	�� �?�"O�?d���{��ָ���d���F�b�L���43��/x����&���C�5�*�d=�nȱS0~fo�Yq!u��2���q� � �.�g�~�H�����!�!t����QL2���G�pw9��[8G�,�v�{W����/����,B6�W&.\����ݟ��˃��J��POc�Z)z'[�6Ȝ�G��"h&O���k��L��69�5Vx�0mԘXQ� �5����6�8���|r��5���ӟaN��*�{M��L� ����(X���I�;��;qZ�>�o}��J��'"j���+�"���P6����|v%�ݏ$�.���MUHt�Ho��;�@���6����8��ē����W��w>	��+A}�j/@b��i�_7����
�?J����8�WΪ�K�2��0�^]#K�,!��w�<ǖvۧ�Q���2J3����*���N@����Z��m^z\FI��h �� N�Z޼�w%��̵IA�����^�����X�D�{=f�yPmV�V�
�۾Zq�8�R�e�C��33�T���F �{�;���㳼S._��C��
\���nN
/�Z�Y]�U�K��oI�ҧ��t�E�T�Y�k�S�0����9I�O�w�D��`�t�q��a��鱉P�1M:�2��h�j���Qd�����P
��𥟭����r�v���|/n�Q?O�
S�U�s!잉�J�-�i��U�n/ܨ���l��Sz_� )�*"P4��4��5�r�]�����_���)�����T}[�kBT�>X��5Ğ�'���c�����Q��������B��n�PV�_a���@�}���rE�L���2��@.w�s9u�
&%���@<I o���bb��F���lq>��f�`��}��][��Р85c�RE?����q�m�Ň��D�nD�v����P�X pC�Z�6'U���I�m?�8�2@H�#�`�NcX�(G>���~x���,8w����r9��d��[+IM�Z{��e��4�ÂNmYjTqb��Yd;�Ҹ���{]jb�,�������C�%]Ȩ��. ��Rc��#5��آ�r'�$&-��D��i�8mn��C S��U�@`�ء2��$�^�ʸ�rM���=�j�W��t�VZ�J��eA��_m�2�۫8�����R��x��٬���a��|$p�5���mLkFX�����~E' �0;Y⤞4�k}��hVd��C�ʫ�hz���mⅧ�<zS�w�=��x\�v�������y��tƞ�㈵�d��j�?�*�&��嫹����2{:CM]�g\I|{,��4��GR]�d^-g�-m:�?�����X��h��$���'�/��nv?�]ŵ�Y���6˴®�kB���3T����IM����/J�bz��\0CP�,^j%����Е�$]�s���� �|T3���Jm�<���;���zk�1S�&�6<�[P��}�ׇ���� Lf� K�8�	:K��f�+�_,h|�+>��v���`�B�Vi����4���@��z��}�"tM ��Ǹo��W-�����F����%������	�G����)]���0$�\���iZ{��
�]e�UMUE��@t���֕���,u�p��<*pj�Tlw^�]Woo_������z�����(�u�˱>�l����΋��*���@���iU�Ag���~���x�<w&�O�fN�p*��y�.�y���Ċs�Q[�T{.����+�J���M^j<2�{�/���o*�"�$z/m�X��
��xN�[:XyR,�^���k���(��%�ˡ�F�Eh�R����֫�$��2�åU�\���4�����J����E�	�4j�D�{!\����jH���-�K8��D�˗I��+�,ij����F޹���`5ɸ���׋B�IJ���)�<�+f��>�N��Nr2T�{`(b�a���@�o%��@,hS��H�-�W�n ��R)6�Z0��~��RE��������Icu�m��
�ϣ� ��^$�e�
��N{�m�&�AlH�}Mq�v���\|��&4da�)�ZKq���    ��so���T�V�u��rm']gn�FT��ɥ^w����d_ﯓ蔯�(��-;������N��88��ꞎOt����E���D'V4��}O���_n [�~H�J��4���i��ʟ�<z��,B�ӞN2?d���'V� ���Nߠ@��.��L�g�,�g�	;���T���'7i���J�"���}���#��_��'��Wi�p/pB|�BP��w����,���..����D��2�&�-�Ш� �t2p=�%Q9��Mv@�r��ԥҗ��Q%U�w+�����S!X����W�\�¦���6$�ȖUR�vMu]�&�oY	���z��uQ�:s����C�&b��w������>��Y��C:T��R��Ui��~ε��әK���=���#�@ZMt4��L��G'�5�hǲ����VH�1C\�R��h\�ץ�2� (qjޮ�WԊ�5:�v�<��n���	 4��%����z�x����iN�b �Q�(K���$\%m���Q���?��?����a�Y���!�{��Ɍ�5<NK�'��=s����N�����Ɖ�{b�Diׄ�
�%{{�w�'?m�=��K�>X|�=�ԋ���=���FK��S�-T3�$��$�4�G<�H�7<�h@U㧪w\?�ʪ9$�H]�y��r� |�������M�t�'g��tr�U�|vJ��P�.��0�vl�tU��+N�����x? ���
m\8�9�J\����<�k
wE"��(˽�#!�v�z��;��}s6���*�6���ɒ̨�_�d��9��,��9;�E�5g����˼zQf�X�a%��F���wJ�������Q�X�IFu߾���|������8��nB��}]ݞ��4':I��[���(��w�v�洃�&;(�~���;4(X���P��^�=�3��w�npY̲8�n
[�a"�4�|�vmRhdM�B├��2��:�f�-���0B�/���Ӳ�����a�JViZ�+�xY���Ѵ�d�њ��7x�t�>��zs������/ز�{P�v(��kOL]���y��=�{���{V\Q�܍��q���.r����Ww�tj)kL���V�J���'����`6|]��@H���ѩJ�W�;yQd�nW�ռ�'��?Y�w!�����|�0���*{E`=l���3��&t����n�&+bWxJ@�8zK!�0�f�eϦ�\�ʺ��Q
J��� �8	���g���,����O�"�E쾿�I�vA��zEU�NG���[�jZ�-�ˢS�P SQ��}��,4���h��a����V��*��4�
�Tf�į�4z7�W.Xoau �� %kf���=."d�l�zS�s�v��k"T�J�N܍Az!X�@i��u���a�w!U�}��.�F�Q5._���M���kY��L`���f}�R6}�����M��̣_�����M	+�7b������ �(	�u}�lԇڄ�0��$&,43�J+�^��ĥ�`>q�燎;N�����V�������@9�r���[���e@-�ӂ��2��D�@��aԖ�w�w��6����lE��x�-�H�c�uOq	�8M|�.$�*�ѽ7[���h��{V`
O�o� ��>��P8"�(�D�T��-�~'�ɠfwY��y��I8��dK8�R����GjQ{����0�g��i�b.k
���0��^�j~�˸��½�u��1(meuʛ��� TE[}9�ӌ�P�<��6Ym�>b;q9�[���>��`�q'���P���jT��_O87�� �Ǝ��w6G�����5;ъ�8$�Ӽڼ5uFԒ`����F ���Mh���.�&�7�u7^���谢�>
�9-��g�T$w�A��/��W�me�/_��*���#��{�'�_~B2%fa�k������g��E�*�����OiS&���JIˈG��x�"z�^�A,0<�c|�z�TU*D����awl��+�"�k㞊0)�5eu�c�ǅ)��M��GJ;z��G�+�VD(�8\����qnM��+��y�v��}_�����z$����I��h�+}�T������}(D�>~U�#x8�*e��"�D�[jt?A�Q�!T.���[ e�S��+�� �� 0�=5$U�f���^�I���rY�?�C���p���c�H2�N�z���9�Z��� �B�p�Th�L�Q���
���kI��)DL�5 ��"t-"v# -.��_7'��p1�Z����*U\��������4'��:�w�{�7�9���Uϒ莙�5�T��9�*.�՝�}ũ�t��y���rmG���!�˨��/ �$X���$[���,Ms�j�;2�4)��O�F�6�S�����V��cy�y��4�c����Y�E�"feUh��eя��H:���t @�=�������t�e�Jz��LD��ҫ,�ܱ<+<�����_Ri����]���y���<��������@�K=�Q�|O���/�,��d��W(E�*K��[qqsH^jL�H��Q��;h���� q'ټV�d8�P�k�����<�9�â7Ý�l����幍�3���/Z�ًB�g6��Ș�i!!�t�����# ��Y�S��~&�s��&"ہ���Ua%S�m�fmJ%m�"`�/t���ͺ;�L]Б�1RX����ˡ�~�9[�	�;l����ɠ8	q賈	a�b�G�Vρ<r�'z頬Di���H�B:* �Wu�i!�34>z�r��^�]I���ۣ�����M�}VI�n���о��G�*l �G��3")n!��8J�oj1)m�;v����T�{�N�����@���A�9�+��f.0�
��	��̌�V�Ds��Zf}��]&�'����CH>8��hI)�	)�E�Lf�8�
$��M���T+j:SU>�q�3���m�)B��8��i���z�2�e�����v��$mV<r�(�+��@;�ngO���+�����h�t_�'?D���kCԟ�}��8Se�[�4��Z��<�鸁��6G%�ߍ�?��w/�#����x�4Ѵ0�D�o���8��E�~�Na����������r�ҷ����3��C$��^�~���;Q�b �+/+�цC$�^X��.X�x�3I��:-aͰ���%P�E'a�ghFM-%�L��/�$�+�F1ΐ=�x�c¢?��F	^�Qz����L,]��9q�Ҽ0�b�=�#�uY��2k�,�+P�Y��6t�_��YD>�����Q��6���S��P�E,���¥Iʰ�{��03�z[�+BV�U�߁|nD�hH�#���fM���KAUeXր�f8�����n�Vi���6��V�b�����S^�Y��؟��n��eh�<g�@Z����l�2U�(�$�P�v����5�����fW���.>�&�`��j�+9/2��tr
��"�4U��u���H�<�E�ePj}�p`����홝:m�F���7W��[���$�M�p-C}�iD�Q��6b��܅�s��A&��&�g\��7�<i�u�6�W��smZ�2�B4�@;��uq����
�#�f�Et�SQٰ��pUxg+例z"�J�2��vu�ImZF"�*�>��-��D�c#ܒ(��f��P��!��^|���oN;:�j�E��	^c4f#މ�$������-���]��ea�<�#����&]��Ydi�AE�ŚKW6C��l[	>�+,���lF�?5m>4��t{��'b}�H�����O-��%E��)���V��������=,p�NT����6�?yDכ��!��� �
�:��,�hcF1��2�MM�^y�%�)���	s�����ކ�c�@��L2�,���Z�-O��
+��e�~ɳ��V<���V�E����p��P��"���L#,�>l�U�y��4.rc�\��B���Y�����������j+��Zcr!�;���{��P��*�eEȌˮZ��!���A1�K���Hy�{    ���E������l�O^�2q`ۂ`�5���
M�2ˌ:a$U�Uk���%��=���=�G4ϣTf���{�b�&��/��v|�lD�[a����3q����K��,*E�L����d,��P�+��X�}�S���CWU���ǂMTr�nEb��㼋2��ƈ��n��㿆�?�#���xE �����N��r���������Y������6_�`+��g�*��e~�Ը�Csb�;r(gp5� ��1Y6���X�㽰��9^ĲL��^cYU�5�F�B�i∆�'alyO�W����7��ΐ� 4ˆ�
�h��M��	L�j�k���Z���"�7�tq��-�K�q5�˲s�QDs��&U`��P�U������J�~*?�4��R�X�Ϝ�i&GkvlĤ@y�y{=�8~��]��R������U�E�R%ذ)o�$���3If���\�zm��� ɵ�\R7�'��]NÞK
]����Ӈ�p1i��ß�&I=���M���W�֚47�h�lY{�x�E;���ʊU8��=���%}���E�R�L�f�p�`_ٴ\�����^�A�[|��^6�Ž�E鴑~�yC�����l��Ջ����O��.cZ�2��}((s���^e��Lԑ���v�!A�CQ_.Y<r�sO����jh�����#��z�K	j���|��UE���ٸ�Ƌ�>�H����Baw�^�|A]��O���� �6��y׼�|v�{�6�.�t�}�.�y^�e�ٔE��"s�{E�)\��G��p��&܏˝��?轁�r>\� � <�a
z"b��E�2�_�_{U䦌o�0�n5���+�Ջ3"���]��U�9�Y�K.bd���9l�[�2/Y�OL��µq$�����q8O�T��|�U70X���d���u�tXQ�`�¸BzE����������K�����^g����$�)n<bH>"yQ0������3��-��_��Ta������Pq���'y�h*E�&�A��_H�[�\�)SS�u���-�&+���P�Eo���)��Q��֣���T�<
�<���2!e���Oڲ�S����@�e����{�+��(�*���F2�Hǘ�0Uݫ`#;��4#���b%��S��T�
X{/B�r{X'�lgQw�
���3�䶈�!SW¡rht&��N���-�F�j�U���KVm���14?���P@y��f�����K��b���Ų�0�����ɥ�
QPz�h�����q���e� ^������E�4E�"Xe6˪�?C����xʫ�:�|���K�v�_���[�U�)z�N�D�ˋ�����f��2���u��y������;�+"��-���ga��B*Il,\̏�^ z���z6x!.Vk�ɠ�x?�Q0᧙,�{O����wC�����b�5Z����@B�p���S���GA�|+
 Xs�a�d_�O�����{P.�8�O���j�CM�ˡ#�+�j#���o�A�Xz�l(���9p>�-����cm�WUX�p�Ң��
�l�Z���J�h
)S9qE/.��U��}˂Uy&�����]��2�M�;��m��q�}����JGg9���C�9���'��$m��-os��k�����}�y8�牭������#%���g���.�`�ܟN'o��'�K�Tr�y5� �A(���b�B��.��,��_�E�T�[�ha�X�B�@�`ԫH٩ؒX�ΣV�_&9��i�B�ݚ"���e}�x�[�	���fEl�/	oL�Mղy�E�LfMX��pŮ)l�b��i?v��[.������󡦭e�{o�p��]�?�X/�U��P=cJ�Bz���w���ؖ�kIu���X�+�>���ra�@��l��gt�VP��2�3���|MԬ�)M����u �)J��$��}�n�<0�I���}8K	S�����rŇ�l���I����������X������#b�.5�N
��<�s?�O R��V�4^&4�TM�B�����i|�譈�y�s��C�k���
�q.� 3B����㙺[C�-�j��U��2;%�5-�j�9:�n�3:�Rv��z�"��#$AAR��vd��)�o��E��g�h=H�w����sESJc�3.���t��Q�b�؉|6>T����]�.IdW=]�"�U��3[�^�ז��e�j�� -g#,u��ٰ+GQ��[����ߩV���Ş�}����w�k������o27����^�tuI�1q@�q�W��u\�Q����4fĻ	�w*��)��c��̡G�i�[�)3.┘2,�L[˴�_aX�E�aO�|��X�� i��(mw w＋��"Bin�{�fӷ�
��2OF��
������F��#���za$R���G�����ZQ��i���C}�[J���9�V
�+���ϴ9�򈣼��
n�n���r�^ZY�$�_��L��	4��ƴ+�C�"�b�L�ծR����\�	T�#�"�3�.4G�!���W�"��;�V�E�c��B�eه��X���>�,��=f�2���>v������+�;F�e�;��{O��ﵐJ��������}[X�<�<��F��W����PYgiA���:?����X,�R!��j� �8)� b���W'�Exm���oјjMx��O�2�'�8^�b,�1Y���ZHv���5u��x��sS(R���;O�m;�d45W�~J.k�_�cR���抪�y8���y~>��iR��M��p��}͊�J
�wK�/?v��� &ȠWkJy�}��,�u���c�v��^�U�� Qo�?���@�55�����Eb���s6�k�zQ��B�w`��+*`I=�Q h\�����������'v���ȉ^SÅ�;5�ݘ�3~?��5G3�BI���8��+��R���^:Q�����E������M ��&Q����M��̲�<\�.?�������b?�c[Ņ���+`K+��
�xzl��u�PfmY|e� �D|�bP��5`���@���$�+��Pg{�*|�
�H�?�ϔ�#�w�a�U���Qί��m����r݌�,��U�@\�dF�j3��d�v�>�I5�1�q�yA��(��O�f�f�L?h��/
s����=>O�c7�6�evl�\ TݢB
Cʳ�&� �IDH��Olϟ�Gw�i[WW%/�h����O�8�U������JP�F4HG�cl.��� ����?���̞��E�x��7݊�U��ˢ�� ��0��hF� ��
�:ڍ�U[D9���e���SG��I�rg���w��!�[(&��!�Dyi�"N�ʊ�^	$?a�W��i�3]�V�y7�J�v��|�l(0[y��2̐2r���[��j �sO�E�Ě�nWD	��?��L`��Ż�qz�@;Nt�����SEi"]����1,3��C6���6i����*ɫ��3�ɑu~:n���a�4�':�-�;E!�٧#gòR��z�u�W�;�8��ā���i���N��/#��e�#\��`�Q���V�PRgu��Gl]��o��∕]���.Ƶ�l��L�*�;x��).�d��:K�1����Fm�C�TB@R�=��.v�,d�3��~�/u��=3{��/�F-%�)�}�Z$C؜B��OV8_ X�[+����'0��[�8\��<u�o�����q��%�v�����J-2>��)y{x���y�.�kU�H�	�"4�]�]\�&�}�d�wR����
����U�-���U@M�+g-����]ZdY`�n�2�����QZ�%e�h�l�s�|OU��\�S��Ϧm��L��N0d���,Y�2�}| ��B�'�^��"�c�meT�.������yr'��[������C4�e�!kF���*��	&*g�f����yQ�V#[Ew���q���R)�U�������έ3��������^Yܢ�� ���J�L*�tۚ�]dF7iG����g�%y�q��f��"��h�    �Z,I��]��x�9!�Ga�p�awX�H�ʼ�3[�E���A�-�$���m 	�������F����a]�ȸb6��x8�:� V�aU�}�4"�hK���g��%��ܙ{ޏ"�{�N7�;�෪'84<,1��u�8psL�,���}~^�.룘d�/(z���Yfn��r2`�vt{u�p��8]�$.��2��"0v)��Ni�~���\��`�� ��{V�q\�v�Cm-�!�L��/����'�@Vex�l�_�>�u�����$�3d���$�଻Q^��%�ڼ_��"B�F��+d��a��}���B�E�K���\H��&��jDM4%P���>�v��8��6s����s9rx��t���w-]+zDx-�l7��b����^JX0+H�ܦ]�"���S�R���μ��:_d��n=N��'�����?��������T�c�TY�/�-)��������C�ؕ��{��>���v:c����5 ��=�|����"t)�/aA�����K�rű�c�zl�|�P�耜�	�X?��O#��Op�K��$ΰx{��mg����n�&"Z�%J��8�8��X�c��"սyb(E��5dDȺ�����)"/��
��#RWI�l���UTY��J�wt'�1�I9>U�1�H�'���6�̺Y���εh,"=��,�t�3�����X���*-�m�]�]����L'�K�Den�d�?SŢ����j�L8Ǟ�=�ք-�-UQ�m~{��'�e`�Gw��:�O_!A��'zM5���*�K�$<��ū�_��l���ª����W6i����<�?M��'a�c���+�^���j�+.S٢,��÷*븺=Q a�������u�us}����������'Ջ�7�R�R��a4�M�Ba�U�f��HL�cf�O�M�2�3T��c��{������E�`t�-�%�^�`f ���a��AK�It@��я��竏��W�_�'��ٻ[���z����3��%����;7Wf�EdSS$a��pJ U�������/��*�u�W��!Ur��ƿ��lE"�n޴���N~�,˒��<�֔�\1ח�09�����,��j}�u��*�6Q��E�T�e�Jw�w^�h�U��+�'I�~0mZ�J�l��td�:X�!ϱ�u���d��q(b�W���`x�Տ��J��u���Oh�[�\h��=i]�%�()�K��(��E,+C������\s�wv ˢR�4ˢ��:��[H�Y����l>s�$` �|+/Fa�#F���| ����y���g�H���E��$`p���qc��$�j���k o��3Q{�����rV癰�ؙHn�j�=`A9�˨21Ew�H������rj�['u��0��
�"�����'��Ue��S�k��W�����lѝ�m���
�='[���ڄ�dQ�s�P%\DS[&�wg�MK�������N5P�*�F���ݣ��s�\"@j�y�`Y��ZU�Y^���-S��l�a��ix���a��� ˀ�,1a�`��:O�v�*�2�w�t�ܷn�jH�������{6��鲑�
EB��^et�@,$������c�n��d�B'Qu�Ś�V��養�)�𳐄���n�{oT�tt��gs�,�ڏ݀�WŴ�^F)Y�E�S�I����У�������U��=
J�xP�*в�[@�D��>�'�<�G����jY��U����
?��}3{�t������2Pw��%KQW�=��4�&��Q5 `U�]�8?"I`޷8o����C�)��&Nּn.��`�ǒ\]���#��U��TV+�\%��v&�r�}�E���!aɱ��ӣ�䵭��T����;����}�_�2�������I��2]��#E�tŻd*�ݞԔ���l�,��Oy���;��r�c�B�Ԟԝ7Z
e��}�	��֢2���Ѫ���l�g4Ŵn\B�@�w��P���tUu��
�i~:�'��{�TL�OT'F�l����~XЮ�ǋ�*,̬�.�$��m��)�T����f絯;�<kuG�Q[����{O��?OH���s*8��������6������H����o��ϋڐ��]�k�
����M8�8����W����G�݊�ܿ����$b�Hs!�gA|z��=
]X�a���9}�]ب��h j%r
e�S�^m���o*�4��]!�]��|5x�RN�e�q��SY
R�`�/�&
���Q�f���*��f[ܾ�H�ܪ�[�g��ۄ�=TN�O�b��oP/*��KZH�a����6��Y؜,�����>��NӤ���V�%����l��؞�jfwY� Ty�z���!&�q��6�-�$��؂��T|M��z��k~?�pT��+N�鴏��z��I�C>���<a?8*k��|[("	@��K�6'�7|~&���R�#�M��r��Y����^�3��^��(�"M���i���?� R��/���a�R��U��H��@ѧZ`+�x�ؼ��)T���
�1��8�;�w�z�v��}9�'�-���������vy�"rYn3��r}!S�j>��Ut�8ϣ8�]׍��g�F��������P��q����'e�"���.�z���.�L�G6��\+��Gw��t�p���J<�����U8��pO0B$h*@f��7%��pV%�����8�)��xE8����2z��G5BJ^P�\�nxU�}�&;g��	ầ��]�a~?ʼ\����NЭ �v��T&,�&���S�]qdc����-�O׎�1�a����EAGl%�N� ��4��,�-Lj�6���$7���x���h���?,T{�s�@�^���g�`�Y�£\���@[|Ь�EZG@���:S:�cz��߆��N\ϘS�����g����%5��g�=>��G�q?(mԿ"��o�5�w���0s
L?��/'�p�8M*����;��ƶ
���Zl㼵�/�S��Fa8E}�i��n\���x9�5�����PҀ��3gr���u�@�~����6�L��a5Uk�*���aԌ���_#�|�0�y�\�}�ur�����;Hf���0�eD]1��L�e�f&^� Y3nh�4��:H��P'������j����RlQ��sK�o��LȢR�����=��I�P��-PE+��2-2�Y����MZg����%5�\a�E��*�6��	)��@�i� %�Q�l�6�n������$�m��x��,}#P��'/Q��;LxO2��\iv@�����ncV�V��j���͋=���k�{�c�l�8�V4XU1B�����Y�Nr��Q`�E�`�E1�F�����PUY^��ܚ��_�*����P��s��:+l�*_w�𧼾��>eC`�`�߲�}��z�.پ	M�8N@��B����˶���SjUX���2�$�E�uh��@a_Jt�����K�3�\Fx�W3��4թZ�҇˅��E�RM�d��f��+���~�S���@V/��Y���.��ݖu��+bQ�J&(*�jaE/�����y>�u��y\�L �Dy!���(S��b�_�f�����Ѝ�׀Ve߭h�'ꪝ�8�B%R��$rw�!��p��bG�Os�ЧЪ�@�d-�f�Y�4��Fl�4Km�B�/��=�fE|��S�Ma+�`�0���QF»�U�Aч�#���յ��B�tAT�2������U�ۼ�oG�fY�����}@��\�<��ic�r��}�.u��,ˋ��,�n���ey�jG�R�"�L%������F���dٽĹL�����NXc�.;g�:^��D��E����a;�p�7�6)�5���%pw����
y�"D��ߜ9���ɓ<쌧��N#���~ۯ���,ɴ�6E�z��{,�� ���(�a*�~Q��L�s`��E)���";��9�Y��c��_ۮ��xEL]ìմq�ʷM�u���c��_m�.t��P>�.3�'�ޟ��`,�����h�<�w`��    �3�~N��_�����z�/:�y�&���>R^�Nf��gq7"��2�v���Kj���
�۳��]����ԁ�@edx��q<�u�"<�갴��If�Ԏv��h��p����2��\ �h+.�&�p�G���hrS�d�X@��8Z晘�.���cD�z4/���;�ep����4�	/"k2W��}.��	��ަ+�K[?7e�3�߲�U ��7WY��ƎU�Ekl	���<��\0��&)m�"�ZST����{9�K��^HF0�rO� a��L��R��y�lQpz�=�p�B��]k�F�q��s��T �p�BCu\���`Z�?����?�S�a,]W\��)C���^Ʋ��66���硚dB�3�Ē�=�� ^��6@6iط;�$8���v����
�ސK�`L�&7�
�n�8}�l������5R�|� M�I�s�H+��1�<XUΉ��LEQ���y��j]��ǯ_7�����|-Tߜ2U�}8��7��'��7�i&��Ej��m�l�ߘ�ɺ�i�U�嚉�zW/�H�z��Õ3|��:X�D˹A�,�)����E�di؉}�Dk�n��H�dq�UDwbbx�TG���I9�b'ⶫ]������&�V�L�����66��W�8rW��є5ѿ�T�����k�Lj�2�	D��U�u��'��'\t,D�W����n���[|n�ٔ�ٮx�~�����Б X�8��U������Ď��"�2�TL�n�=Sɨ'���`G�����Yb�4�U��Jy���dE�gx�5�e�V�b��a'�T�����w��5��� *�Y&ȯ�� ���n��ɳ)�T���)-(;oj���啭:�3��oK���"��t�i��U(pr�&���"�<ڣ����|Z�	"��J�[��j��U}�	���mM�o��Ȕ����$z��dJ��(��܆>2��C}?Y��ˀ�$6/T����z�"7����e}&�+�QH����L9x��u��K�koJHO��j�~k�5��F�2�>-%��)C�Q��3̪i}��FQ���2�^&S��e�ʜ�qY�ZWyu��3�E�zeAi��o�Tz����ƻQ���<.�չ���u�m��ˊUƕ�˗�+�Xsy�;��ql�u�3�n��F
����]���e���z�k�6-��fyi�/�J}q��{�&*︸�������yY�8�?P8zg��U��HU���W�F�9�t��ѩ$�^4��=VJ"�?qb�癶�<f���lXJl0	�6�������?GP���V�ix�D�fܽ��Q�q��/T#�-���A��h�^V��Z�wg��^�� �/J�!���5B!T�2b֦�+����tԭ��X�µ����/bGz���C��0.���G�*xr���L�I)��{�$+B�ΘҶa�*k���mL����x\��${X`�tO��1�PrVư>Z�2FUf���y(ˎ�4�
��"5��Ϊ�h���I��@ L���l��N� N~�#��,Y0F��wX.�+�.��O��P�*����"K�yY	��[i1��!+�W� �j��E��^��=g�Ȓ8\��K�u�f|]@���<�iF~>M�/PE~jC|Ⱦ��*ws<�j������U�m�ɚګȳq�Yѯ�v���ZK�X��>�g���n�<4y��P�`��v�wM�"4.2��T&wl��O��\1��t���F�kj�NY���2Ze��/T��m�*[���s�L��'P0�T5*����٣�_m��HM���GW^��K ���w�K/a�`�J��6銚���+eA.88�fQUs�gR޻�O�"6&�2��L����Kh�5�XU�G69��r�Q�kT������կ�:��򏻭1�}P=����歀2(�Go�������
c=�"\�)8�}ݬ@�6OX��_�	��=Ө�%�8s���[\�˕:�]��a�$��k4x�_��fq���/���_Ѫ�q��&ѯ����
��؉��U� ��x��CabR��q�Yc;0}$��V��:nk�%eӬ��IUu<��譗҄e�k�����v�H��Y*�"�lX�e�Ym��zM�Z��n��8�~��3�iQ�u9!6��s��`*���\;J�-�-�nX��U,:7x2�{������D �:b>�SZ|�1^Z6��@5!�C�?���T8A��.7G�S�_�i!�rf��fV�i�ODt�H��<̫�k�Y�+����~�s���#�M4�z9
LcӃ��n��U`�ȁ���UI���]H\�r��bkW��U�����KF��v@���s��hbA��!3��wi��Cl����.�h�2��G0L ��V �\YW�����D�Y2�	�E���y�5w/���5����qU�M�����H�m�"VUU�X�����Gٕ�a4
�	�r" �:�z��	����c�����-��df��l'E�9T8npg��
��~��2�胫;D�b��墩���gr�<9D��Ed��b��.g��#��wj�xˏ-���Lm84;�fڙޚ�M�5Y\R�^�)�M�Q\5��R�
��6��y8��޽Q���諨%�v�@[ن�ÝS��+HJ(uA��Ϝ����\.s@J!���}���_[˘��e`��`�Ү����&˼Me��.TE�=�h;�,�J�}�U5���,�Z����5���$���vY��hq)����>�7>W^��ח�֛�G	�����ߧ��{�g~�eX�$	+���ݧ���m��J�UE"x������ɜq�?�,����sWT1��%�H��c���X\l�ؼ̓��4��V�jp[�$�/�Yę��̢��3�4^r�2y��x)���7R��P�}<����ݑ>�O߹���Y�l�	S#6YQ�4�
9fI���n���j#n+[��h6#��+N�� ���R�
���ڸ_1�2?���>k����؎�3-�T4k̷�9\�t������P�x�yMlm�j0HJ�ʭn�1363>��G��-#�«5�d l��3_<�����@G�V|螤>V�	�|>}��a[w���{��Z!"nlZ�����V�Z��fA����p�nR��*s4���y�,J�A�g��:Y125�,�9��zk��	�+�m�1��=�����q���	���rO6�#�qY���s�D$U�#B�Pΰ�R�|v�����|q�aސ��xU@�:�5F��x�Yn\H�~0�G��$���e�8�:�qg�{�^�5�2�^mD���B�Q�Gsۑ�u 9��k�4x:����~�C��
 p}�ph�]��A��t��u3U��� ���������l�S���rq����T����)38�5G�؃��O&�c�ë	�������ó&\�y����Ə�Y��g�+��������v"����]��_E;�;��G�݄�iO�{&��Q��2��G0�U���
��ܿ�:L���y&	�}�&��g��������<z�a� �И��O�(jM=I�C�fުH���ұ������qjb���g̷ط����U�����V�:T�w%D�����h�z#H�O�h|'K�y�m��"��/\���}�B!�&Y��dY��B(P��������Q䙴��~t�ϗq<�*I�K,�=�⅊^�Ekm�"^U��+i��i�V8X2�ET_wM����j9���"b)N^"�M���E��v��2�%^����`�����v8�Msc���x ��\n잁�i�L~b%�j�Ip����Ġ�������`�޺<x{�i)P���$-�̂���3ꙟ�"�����L��F--���ƚ��D.�@��A�D�qpZv��!m�k�<��T�b�\Iu����T
��]\����,S����Yrm�M��
m��x�;�N�����&f��Ҩ���͹��]�s�<{�I�����7;Pg"K��Ӱuͱ�������>eBy��2F��w�	�]H'���a���)�Q0oZ�(,o�p�W�}^�O�u}_�g��P�    *>�4�w�	��z�w�i	>���K����]t��G�DE�D��q����VdOE2�T/B��"/�n��%��n��w�6R_CYE��#�Z�o���z�=oK��U0s�0���Dx�Eê%���.���9S� �/������HVСl^����,�����<���*$5�۝5��:6w,��k/��5EX�p�~�'��Y�c��K �N��ߣz�0'0�l~>�ʚ*�T{��m��r~��}c�����5�8_�\��#����̳�޼� A̡.���{�h6��t&:�GW�����:�z&��������gq��]D��y���o&[<!��������J����s_��T3��I׼)n�2���z��5�{|a∧Ԫzq'w�0�x���0zR�N�k	�&u۹<{�A�)[��=\�:b�M*���.�=f',4����O;"֝܏�>S���H܀��>�ָǭ�@����*^�.i��IY�QqS�Q�m��;��r�D�E+�_�:V{���5=R�ga?|7Q����]kW�B]�j<p9s�9V���J����Qjwh�IѬ5��祉��Ǔ�*�;W�E0�E�w��8����M�-T�޳�8���MH�Bm�-�ZP@���z��O������Eͭ��+�uU���̨l�li�WN9~D�Ip��6zF���I�����&zzx���U~W��g�=��p?�����=|�>t#�W�*.�Z��)<^����ǟkfw~��/�`qp����� AK�� ��*V��	�|zX�����^څ�]�/G#^��
yDnfv� ��v}��~���g�x?�=�*��n]a�~��t䞲*DGQؽ{35��xb~��R*��8�Un��eN7�8��+Np�?�6z-}�?1�f�t����r�|i"�k����剺b/��yv]��xJ�N�y�G!TF������(�ե+�ʈ�y
J���&6��O�EM�d0�	�5�N��mg� �)L]�M��T'tYQ�YD��'�vp%����ߏwj���R��u��Y�&q�4Γ쥞*�4��u��#D#��7�g�hNl�u�h9�`\)�:�W7��-��M��x��|Ns����#����r���9B,�L�5aV���7�>Q����Z��xBc��𬬬7���w찣�y�^�.ɞɼ��xx-���%a���T�U��+m^�>���N�O��	��;�׳��q�#�6s�\i&�f ��#����E�GE�W�h 4��2)d(p0).?�aI_����qt7~� Y��6ĉn�y��N��h�"$]���~��H��N)s$L��cb�� 	�˛���E��2�Ό�<�R�3�n����t����������ً#+��%ԡ�.����k��8/*=��7�%��o�����S�|�:�)�XH-�p�n��w�+��γ���{"�y�cdo�է�J��3�=�H�� ��� ��EaK�n�q��������P^N�u^�m�7��⍈�I̩ k������J��U��0�7P�Ujnk��}�:�]'έ�`�UP��'�]���p��]L��E�lV��:6�m���um�"De�&�0�跎�.�k�&�YH|���͹�"�~ذ+��u?(��+Sk��CA��$�����JK�z�m��a'��Bt���\5�U�Bj�/��*�������P���U��w��&�~ߡ ��
� vGq��~����1RPB���,�;1�������D^ū�x����J;6�/�Wq�X�2�-u�v�
�\�Ĺ�j��-���������*2
���;��`��S	��3�<�eNi}D�{'���B���V��0�z�y�PNA��rN�=*(�S��Y/
��;]@��"h/�kܝ�޽Ӯx%�����0��������x)���g���8H�Y���i�B�����u���$�O����{�~Su����*��RU;�8�I�3�B���Ĥ�Cl�cb�6+���K���FY`O�P�5uR �����s�It7������_Y���i(C��O���\�3�T�� �z��=�[���~�Q��r{�ꨢ4/�CR'�7+�WP+��2����JI��u�p�=$��	��+�g �&���F��!�O�۟�Br0��"ٿ<�����wMC�X���7��
Ӈ=s��R�5��|�9{��OhF����h�=��� d���w��^v�*����~�_d��X�O'z��|�r�;����»Z�P���e����g>ǚ+p���J
��45�olۯ*���D�wQG1a(�]V��9�	!a?�ږ���</bO�+��S��������@i{O����G�VF�nQm/��ޡ{_|b�<s=O�9ӶN*kW�@WE����;;�G��(�ʫ7ɲV�4ߺ��?x4�`�}�w{�0�(�/p/LI�ݰt�ev�e���ˋ��Id����W@�X�h�_��A�@_Hz	�O�>r����/�hɴ!�z~����}�y4�+n#V�ԓ&Ϛ͓M�ԧ6x3��=����nz�����$F��s-mG�h� �a)�]�ؕ:aaA���-�5ի�T47+l���+t�辋e5���>'�t�j��]t�M���q}߻���9���2,�YfyXͥ`d�:�|�*m�:�p���W����T��+�q[91?��C�^��;�N��4H@��+Ma�**�k�8.��7��{����ݱ�����"x�%9y��E���	L����אS��^�[J_^ӤaZ�4ɻ���8΍��d&v�{�q�F	wio;��}+9w_���̒�z����4��=`�a�e�I�/�N��5BF"��!P�y�[�]<�6��������I�i>0it�_.i�75�x[��b�r���H��j����Js�E�䰶�<�5E���@v߳��>R�#��i��5�����Rc�d�u�l�n��ɣ߀����p?:,紌�"�N %���1��P�ad�}�n�4�8]�s*�`��Av�F@��\Ed��Z���� �E�K5�.Sd������5	g�b�\x��$D8t��Kl�Jy^�[�8�ӃPvnuZv��pB�h]� ���c�J,�h� Y1�O#hhoyQQ�iǴ$� 3AU�y(QIy�m�ӺH�%�ɦ+o��."):�MZ���m*�Kֆ�Z�QE�(_?��NXN��0<� v��b&��&MM�A0�F�n�m��Z�(jXK?�:{������{���X�� ���=�u���O� ʨ��/��X5�
��� )˔R��_��Ӟz,B���9�p���^e���������G����պ���\������>��#�w����8f�NJ6 娄��.�2�����Pv4A"�0:_8�A�/X!)�\k �ɟRD%��^w����y8�Q��kc��-�B��i�Պr�V��2��X�$�3S�&�j`n��3���*��k��MX������CUZ�ɚY׮��u���U�h=(��Q<������\齬�KS�a��p,��/�>�=>�GE�$��B��$F�Ԣ�Ղ.�+o~͘'qET�'`�u}�;q}��\U�&��\0�CWm{������4�@����/��s/_EO�j],��T���-S�*u�>s�Ml����:��G7��"��9ܘ%K�����I 2��l��3��`t/�(���]f1̅��R	�=��5�ó�y���+%���2����4����6�ގCBZ��RnO�ӫ�{�;�������xG�i� "A��N�Q�E,]߄�G1T���e�ݞma���m��X��Y��Fb�x�<	���#��B^W�I����X�}������'����4�	(�J�Ί&�W�֬4�OC�����]�.ŋ��p�0Ƨ[f�$������ ���yyO�fɀI�|��	�j
Q�Vk�ln�n��g�͖#7�l�g�E|A&�s�pJ)�Qf����  2*�<1$����k����    �0`�u�:�5Ե:�o�����%�ߋ�.���S�|?���(Q�T�	���tZb��J��:cIQ5�������;��6�"6�X%��Ms6�ɋh��.n4�%f�_�ۻ��s�&^�`��>��Y J3��YX�D�cS�*T�/��!Ы|�v�_ V��R�J�����qU��0je���?��޾���:M86MH��(���� a}ª����4���
��a��a�_�և���5u��ȼ�*P�hC�+�ma����1�
�e8҅Lw��en"�MD�l}g�+3W�A�ޢk���O��ds �������8ͺ�������(22���EPR![(B0p����S."�"6��ؚ"����i���D�f��q[$�p�1�P{�e�!����/V̹��S�Z�B�������t����MU�gl	},<a��mӞ\[q@�
=�@`�o����<^��c%qX�)�~E�\艭I~8�����סɝ��G�*����W�>
Y ��\��v�{���MYn{{{�P��@�~c19�F���:}��r{�#C_Έ���8�~I�yԊ*�"�'G�U��+����#��ɯr��9�Tm*��Ϭ:X~�0H,�FO#T���Yנ�3����R�j�	_�c+
8"�+�l�+�n:�D�H������M��𽩭3�ssW�ʚD'vܲ�VB!���x5{�� ܿ �S����wL}��O9�;������d{�0�W�G͇v�����#�W^��$���Z&J������h��"�q"�<O߶���BnJԂ}=1����*$�+�D�)�Q��簻#3@hg��������j�1�H�����S¼*� s��*�;z8�_֟h�FU�h!��M��EQL�_��_���2��ߕ6.��j�'\T5�x��QD[t�tF���Op�XD��,.�#Z�U��)o�1�֟��,�(�*7*�p�=S����ec	��&��E�f;��o(&9����s��q��u@��Dzx]�	 ���S��~)����q�S;ZUַ]}{L�VZ}�\�@�Z��dz!�|U�'q�Ĉ錂cRAb�4�T��.����n�ԧ��ߦ�[N[L�pl��	��}Qw<.\�v�G$�m�1P���d]�VD$��L�L�Iؐg2�7:�`u��w*�������#Q@����q���E ��j"�$b�W}�`��[�ȳ ����I��t�Ȩ>K�pi�y̱�дq�٦�܊�(�l|����s�-�����D��7��j�2�Mt�ǭ3�ٮ@��B���B��4fdc�# c�:�#�:!�x\!m>���A6�u��2��4O��QO�+~t5���?y-��F}�"X*�=Z]��n�:���|� �ֱ���%n�w P���h2E������@Y�g�bO_����C�J�8�HRc�1Gؽ1nQ�T:�j�R�z�<�������ش��7Q�4G����h4F|��)x��/��1LE���
ዢ����8���6��@\��"�NF-�;d*cv��Z�"s��̭1�2���վ��R���J6!�9(9���t��8Eu��|p���a�:���,�K�ԴYZ߾�+la��,���9΄�uc>�S��Qw�s��?��`��D�lL�l�����iT�������4z�Cv��:��*|���`nM�����B���F�Х��_�IF�>Oh�T�1	C��g�ڤ@7�W I�t�<�%��"�M�!ތϒ+fY%h��ƳL>�\˙�F���;�#�v�� �{U�-b���Ȃv�!�E(1�q�T,��r��+}�X�P��mTU��,��Q�8W=)|7���\t�O�GҔ�Z�-�*�F1��JoϨe1���4�Q�)�Q�x�I���8�X����<2�&^x�W��m(�<`R��M�	�yА(�r��i��BY��LY�R�seڶ���.M��pfl���`�LI�Q$��yo6��ز�Q�(w1W��9�ɪ"�;�V�Wu٬�� z�G�%�@�O'Ȱx�#�3��i�q�;�Eb��j����kIZ�u)مt�����ȱ�=dRx��T��'�[I�&K@�{Pe���-�����������b=j��	���p�J�x��'�ӫ����vYQr���y��;k���'��j�厶�ԩ�|y�1j�9��Sz�b�`��3���q9��Vj�6o�o��S�7����	t䋓[e��ELƛ�V�k�W�.R@(�4�||$�{*|1s��{�n_�����D	�@"\�Ϊ:�;��֝V�����ye5hY���q�Q��TK�R!R8��q�t���l$��R0�?���r&��FM��턷�����ꅛ_��`������|��\�����#|�f�e;�H;�%���WB3�k�f��G�Lb'y(��b�8�Ϗ7�N%lU�q�k|(�- ?@B�M0h�<��ζ�����4P��'h�p�>>���S�lb5��/��#J�ɫ��O��r��:?�6��}�;e��p���te�(�<�t�����$� �җ�җ�u\i�����5�퍆I�5׊0+�e�)z��~���T���P	�&@���2�I�<s�t\PYco/�MV���P��V��$�[x�3)�	4|��2J��	�B�=�s��ozT,��5��S4(e���\q�|:��|Q-UG܏r�VW,V��kK��H���X�y�ǆK�z�y>�*2EY�LcU%?IɈ��&��N��XYE�`����K�ED4��v���4iU����t��g����j͢:�a_��|-�n�p�Q?1H�,�X�+�vz�v�����'yƔu��M�(d2B�"t6a�7�
�<J�"i[�b�wb+����A-l�7��NY�f)2���"K6��Nq�"I�a�Hsi�t2*�������]:����}D<|w}��_�9hKHn�H�P���	���/�E����Q[W�OE�R�3����G�8(�@C0�����k�!���_(е�P��ړ^o���8��%�"�~G���3+�p��z��/:��E�{�26*xy*�A](�S���10�.a��b�@w��hnx�5f�� ���=O�m'7�K�WP��[T�έ@��c�(�E������c"��G[��MZ�+��R��<K>��gw��kdY�B���'��4�-���>�vi�!�}lh�	L�2�ǵPY�X�ͬdAV�=f���*�S@���q�����9Ԕq)G�Қ(c׺���d��6���2/�_��)�W��?>�\���{h����Ù��z��Su_o���*3U��Ǹ�����7'��r��OP�\��8�D��v;
�$Nm���u�ϭ�
��&:/����!=�ԝ�ahV��V9�$�TY/wW�(����j��.dsμ���.Ćq��1���G��d��#�c�l�u�"�yQ����e3{�W��o1
\b����R��D�w�C{�O�}������$ڴ,bU�M�
��j�"s���{���&�'5����t1�����DCZ�����X���IeM\��X�/�Y�Y�����D�mٸ��r�2��ӂ���;�sO.�����G��h����V���n=�E�*��UU�俷 �x�M��me�@�a��=<^I[��5�p�r�Y�g��#:�/�ج��"]q���_�[�&�W�OU@�o6`�n�A0ә;��p�����w ��Mڎ���s�t�\���Zj�_�E���S~�{q���y������a턕��5~#Z<���H|�:[u{�.\�[���d����H�%b��o�e�Aǯ�����M:@��`�Y��'�{�=)�_��_}�v��D�aZ��4g�QAӋo�s��?����/dd#�x[ �Jׯ���8�w)߭5�r��ߒ��_DڎnKGaQ^d}I��ߍ*[VpL���Vr[_�qs&3
&-��pC�R��$��H+�G*�܈��rE#R����]�ӷ? �����Hѐ�    �*t��bLā �U!�U���H�yX봰�k�/�ۭ[!IWgU�i�W���=�����# �z ֡;�9���,ĩ��Ƙ�Mq��e����E��?
�|&'�Sx����;�P���s	�ww>��r������Kg"��G;p.��[l���MJYT��	���݅)�Ѝ|,w����PPx�K��ր���ŊcU�R�!ˢND�EV0�	�O��s�u����`n�]Ƭ6�{�V̾[�f�q*˴E�M>��6A�k/�u���q�5��	�l��Q�@$܃+�Ĝ,
�p�{4�+���+�|�u� P``E1�DM8�R/�b	ԋ��nl��y���]!(W� d�O\�F��D��9�'(��U�QsJLa2���-^�)Ը�3+�u�֕��2Kޏ���W�v�w{�:����;`�/���(��'_��11 U.��lWa$��׮��a��9�̓?褬��xa�+mb�#��_&��,ɱ���H�Y�%�wg���㈳^���@�<._*��UU۬Huf���ݗ��b��H/��}��"uZ�������+�Qg���e�|�q��Z�����3�;m��)��魪��>��Z�ĳ
n��zف����d"�.�e��=ڙB�hc}�<�ʬ�9�]��z8|~��wgG�z\'���I��'B����	؅�>ߣ�m�BMz�{�E�L ��G����~�Wf4��6b{s�]����H�Yu�WV#��S�m�ZN�:=9��Q��b�!�ټ�M঍��/�Yh˃[嶎;3��H�̙ձ�F.�OԼ��x�웟�tR��L\y@�S��oϠ�*�X�J;Og�:[q��ͳP�T�ϒ��7�v��\��:C����^���MW,kj��H�S'01���!dOϛ#�`o����>n�s��m�E�\��2n���pMc̊���vM��M<��:V��}% ?�����G��@�N}�"j���+�E��^��iY�p]�>�t���:?!�mNW�R�G�B�'}nt�C@a�m1 
R�@��*��iῠ�9bk�HMZWv+��l��z,M�|����L	�����*��SO=��et\��Dl3���m�����,��M��.�۾k�Ty�(V J��x��,���df|�%)�fe!��=D4�������3�� �����k���Jm�W�o�Ih=A��tt�z|�_<��q���\�]cNgQ�jf���F}#�;��S�x��Z����m.ȍ�"� �R�;q�WU,1����rly�1�mk�Ah4 ��k �(�:�}e���tU;��I(�B�i�L�.!��|�=���#錄�{ ���+�n�?���M��_Vϥ6��&���k�Qr��������^���tl�N��vbz53��ɇ��F@�����lD���� �E��"�dh{��l\`�̑��N��T�DVal�}_�o�/�@7�	�5��h·��2|G���S�D�a��쵲����k�@ӜcGHߞ���`�H���i2��� �Ok��V��2NǦ[� _9����hs�&sE����ͅZ%Y5�����&z�LY��&B�`��)?�?�'��΃W����\���4y՚�3if^���5q	$ߊddL�w@���ho
S��is�_�1sE�扆�h
���13�X.��� �Q�,)��w��y��Ө���E�@u��t�ؔy�b!d��y���������'Rlb_��H�V���[n�,��U��1�ݮ� ��L5XU���jm�q'�/�r�`4'��a6�����X4D�1�D%�>��(��Ǿ�ei�^O��R��#4X��U�
��0�P�K�~�k�T�Kp9����u��<�!�T�ءZ~��·3�r�%���p/�{�a���cڛ�k��|M~���������oqK�$�-
���.LoT�7l�)���Y~wQ�����!�����VeY,���6N�0C����Qg�y�ʒ��c&ѭz:*}7�
�)��@3L���lAF���[_��*�O$	���Ǘ2�q}���=�j0+�|֦i��UyB�^�{�%�%�e�T��OZ�ʽ\�	�����h^vM�mW`\�O�nV�i���:�:��J���ݖB@�"�r@�	] P0��Y�6G��D3sjl[t+J?��R�U�Rz݌+�j/z�M�
���4�i�\���"�+Wj�{�O� ?��#�Av�O���Vt��*W�.R�+�� �d�I��{���p .C���~�U >G�=F�m�[�n�K�ڄ;\%�-��q�@�ѳzeq��cE��f����j�����Rp��"l�ic4�)�5�����TC3�G��K�*K��!���^Q��t��J���%��e��bpIߥ����Z�7]Q�ȱ0�I��c�(Pw�k����S�|"L|��.�HW���wD���7����,HJ(B}4B9�QeQ���)����i�|ov{��CVq,��� �P�S㿃���L��-��_XbM8����;�N���8)=�wS�k���B)��B����ktpg��~ :J>�J�b��E\��ؼ%�����լI;R!��곯�o��
���i�Զ��fn�b�W���4�T.y+�p��%���1��������}������w�_�z�{x��w�ˀ$��nG[X5�!-W\����O"W��(�șm 9�M'�e(4'�@@GH\K �9�>���'��A�g���q��"��8��ʏ����^A�qE��8��T��M�ĵ���D�I�
,�9w-�@y����?��>JI�z�I����?�]�0U�9���h�F��U��w�'w���LK��Ώ�Ex�^�kVy)�<�� /s��;J��.�ijn"b#�mڴޮ	g��-�u�ד?���u̧4yT���I�%��t| +B2��gFkz[4"��&�����?������W�i�C������ s�����������l�T��)��rî�{J��]��@l�$�W�A���-nw�`��l�����]�p8�U��K�a�)�¶����\P1�5����:�5C���1x��s�J�iʿ��,�g��w;�%����23E�J���o�W����V{Ĳ.�߃L�x�����>a
��� ��RخPU݋�U����Iɴy���>9�hU�~�����<���$�%m����R^<���E�L^`\�m����HWD��J{�J&~�:����㞳3`Z!��ϐ1��z����Ű]�v��M�/��a:�!R�4I����
|�;$�/�gHzA�Q���N V�T����U�4����B����e�W%~H�s^֖}�����8)�M~@F�d�A@�s�C�~����C/�e��CN9-�4�=k����ˣQVT�E��g*|�-�����Ⴄ~����NP�|t�jJܗ`��䇫�\s��8!v%����T3�>@"�nG<��˳~��r�Ų����<b�@ULQ!�����������l������c�=NzZ�l*ײ���9�SS����o�f[����6� �v�O���a7�� S�,K@5Io����$Ò�ATE��GhU< ��]�nɟuu%��$���_��]L�._3o�E0�6M�Qi���?�<d��re+���Lr��;��D�]u-��h���vK���ayd=�h�8m�J�Yg�,ȂW*>Y-����8�5�^,��-#c�,2y%�%�.nǡ8gʠZn��Nf(�(�9�a��H�P�j�ϲD=�����jϏ���X�&M�q�`���^�Ppڢ�&m�����ZE�/}s���>��YȊ4M�<2]%�@�Tm��YmB#f�d|ەg�<�f�#�Rrv�����22�f���{�c�#�U�5�5��,�������=�tJX�V�+U�l�b�V\�<�R�)���>ō�sg�v�H��%=��8�������'�N�5����U ��:ԚBf��Z+�"�U�!��+_� B�n�o�P��T;tk���M�#    ?4�JX�)�8�{��s ��b�`#՝v-���N��[�W)���qk�k��Mj�o?�#�M�g�X��8�X�U�ʏ�K�@�v�˨�<�1£1��4�oD���o%ho�4����25��_P��c�pm/F��"Dea"{�[u�Pߌ�!2i��\�|�~�5�{��!�j��1l�9�E6����ޗ6+bT��Ǹ<�l#���]����2�sp�g�|׋�;�m?���=�l9cJY�%í�;��H���
�H��׈��� ��/���ؑ�l�EX*ZS�\��+ӻ�M����E��D�澓6Q��R:41(��
k�O������oj^>h��;��4w�k�ަ.� �u&� ��w�u�FN��(�NM^g�"đ-����/����7�.���|�b	v�f�B¦�x���>�3���Q�~"~���6��E�\^G������)��V�5̜»�Q�D���TJ�jVӂp�uf���������5y�<��զ2+*/��A{��䭒�Xu�V�?��o
a��_�DG�ܼ�"*�Kc_ȪS}�M�BX�-�ꠟy�KҰ�Eݯ8�Φa��\�q's��Y&��ǣ�8_Bw�[������7�.]��l�(s����ߝ����f���SJ4HX精��<�R�2�Z��;dBn
%�37"��v��	)���h�}z���ưz���<�Y�������#�*���uV-LM�����
k�q����A ��#��Е�ef��A!�ԁv�I�hqu�[��R�r�J���_3��2c��a�<Q����@0��77W4`��$���_��,*�p=�4M!�m����+�F�H��t����@�Uy��^-�&��D4sDs�{�VPd�/��+%Nv�
	b�L^�2�� �d��x�[:��(�!�Gjo��1˭/�����F�]o��tV�@2�I>�v��
m����~����+�2�;*>`>d�YD��)�*��|ՊKYZ[k����I�P;��f�@���1��QRH\H[��3t��CW�4r����Cg���|<V�S|��`��L4�͋�(	���/�zd���#�Sc�߄��h����I%g��9EG|e߉�'4�&��|������Y2�M��������5G�#M��l(��v�f3oP����c[NFC�mKߊ�>!����K�_� �ӷ�/ń�NAJ*���!�=Y���Ӱ@P8l��<�K�<���ldǵhE����"�6��,M��KI̞ȄO���tBh���S�m�����,2�T�E�Oo+[+R��?�\C�ў�,@j�p�
p�"
�Wn�+��m�Z�V9p2&�}F��k\K_��?c�
������%|�U�$�y�m�Q�a�?R�eT���dD��h3������@�ֵN��w�
�9�n)`��5�n�Z�7�� t��辆��;�fG�O����w'(ǌD1�ˀО8O��F�DS��6Y�����3S��������U��ȷ���?g�� ��bx�FN��f�۶�����c`r_#���L���Y!�5��m�Kd�t�7Vq�s|R��C�z�RO��@[7Ǘ��ES)�v���>@��U��*x��ja�n�;�8��.�w�|l.���p䄐�� N�1&�i�m݊�e>io��Wx�Pq�G�6QI�<~¡G媆B�'���]�K��"Z�h��^��ee]H+�I�  Y��-���T���	'����[gG���5�i�Q��6ʬ�O�a�v��9��K��������O3�;*)��ج>��bդ��ܥ"7E�F�=t�`�\�޷ÊL[N�<ߧ���Yx�'ѳ��:�/��y���<��Vx�y���vy�YEߛ�w�A�DhZ��8��Q����3ŀ7���Q"M#J�p���(Iz}�c��ӲH���!F���Tڸ��h���+�&��Ԛ|��;vl*(�*��_���w�WxtP3�I��kq�aI�t�^)v����f6��Q���A���*�%̒1E�vE(�&S!���_,�e}��=b�0y8`vE	�L&Ny���R�uO	�я��������H qv7����݃ʩ��"����"&�8^��!��� N:��In�38��rD��{�{�(��=�ݹ����J�r �c<[���������m�X�?���?u�u!�T�u��Q{������ԩ/���j�UA���4���s�ֽJ��e������@3��O����K0��n��R��׷c}�E�ޙ�	q��x�ټ���_� 0"��D�ǿ��s�Y��t��>HC'zʈ���Y:h�P,��f�b�&1�N��&�U���@���Ӟn��vzl��@�(fy�[�}�扢�|���y����`?�y�
�4O�C��ț9؟�؄��b��9�����a�����IF	�����	LE�v��˽F����g6+�W� зYon�8�vz���ӳ0���o>�4��tB�8�t���EXr�6�m4Aߕ���^�(�j��.KG����Wa}
�������A#Oj�l�������G5?x����T%��p~Zvn�L��Rٓ~k�����8�l�4y���J�®�fߺ��H��Œm��̖ɠ矄߮�z;�Y�Z#�	Ďxưڼ���x��G��V@H �.��<a�p=��Y��揈�P%�[�<m�qjn�[|���1�Y���g�RVA��D��O˳ S�S�]z�&>����Iiw�����|�_�eT��������@�I���23��[3�K�Cv���?��[�j*&�h��<SLf�������,������j}F�O���y��1�}�f}�\v��d���h3�!mL�"�U�R	��:;��>���vK��<�`�#Os���POh��Z�^�?}\�Z��y��Z�����~�rG�M�!Ty6���l>���u������&���#Y�y�F��v���k���-Ӱ�+��vo�;+]���pZ�g�3ԟL�64%�4�������{xa)�3�ͫ���h���7wՊ��u���)T2�vO!'�ܞ���sR׋h�jt�M~�*����?�z�Fn)�=�>�ң:.P���t�����@N��u�?)�*��ư*���DS3���|�Z�;��G#J@�TQ���a��0��=0_6�D���6���wQo;���&:���[z�H���t|4���z�[I㲹Y�Hʳ�eH`�r4[8�/�6�Ѵ↪��aeZ�2��U�Eu�ć]�����]��N�ߑ�O���.�L;�y��4/���h������==�Y�p����������ױ�"�	QY�hs�t�ʠ�wFm�4��ZA�-�2�C�b��X���]
�]e��R��?��� o�ܿ�.�ъ�a�jhnϿ���������R����3%�U%OE�C��yl��.�+��]���W"���~�2M>c� ʅ������F2(˟hɌ-� !+�̦q�����>oVH^�&�a/Rf�o���A�b�Dk,pYe
#W�N�dn���[T�[_����*��õC���֗UV�Z�'o�E�e ��$�"�Tx����z�QsNQ���(l|b�ޟ11==��ead� ](|���7��+1��B��D��[8)Vs~6��?�b�:��s������.�\:X ��$��B�p*�����q(Pl�x��^��C�S�('�e�R��۠�.n��z�H������o��k뮏���w�
�*(t���'�fX���z(#u�m�3}��P�Y��}S�W��A��=]o6R�\�E.uߟE�]<KP�iVF��Y%��iަ+�l|!e�r�,��A��T=%�x;�c��SO�G��w�n��3�����w��;Ոn�*	��߲���f'�L\	/ڕR�](y����0�
UeTī�1blsR�[}�o��Z��`&

���;��7Zi�v�w9\�N*o��ü8����m��Fr)�fU�2$���p�RL����i�z�/?��ٳi^�q    ]�b���WR��G�>se*�d|���a�vp�����y�<Hž���P'�<�>[��n�b$�L�k��OL,��U2����!�ݠKk�(�5�z���I�S���C��z���{�m>���w�D6��A4KN=q��N�Pv�O�љY�����;�-^P��/fV&M�R�b�5�j���8���w���+��<xL-g�"�u)͍Y���l¤�A���=7Y�S��i�i�5+ ��0y����!?s�&��/��H�ӖEp��2e��R,�Z�vUS����τڤ�;�N�|��\0Y��}�D�+��!zT��Y�"��Ɗșy��2���kDƴ�vp��M�1Ɔ>�d��'��G
����� ������A1)>U?c������>T�a��^Է:y\E���p��[�/*_4+�����ʦL�}fF������14��Wj��fXs�>����H�"�,�+$W��߿�u����+E~�>ß��l�5����K@=q��������=���id����x-��Ғ#,ʘ�xd�L<�x_�����/�"�Yv1hrY���G���?��!���4b!�9�oa� Ɯ_�UМ<�P	� t�@G��o6��{�.�̘�H����y���_���Z i���;�4����2�t/���gi�D��7��y�=Q�JL�����!��Y5�����CM"�݀�8�!��[?��ϵ�lj�p���8��Q��}�q����$�(6'9I�-��i������j��Q9Eکƕ�?�Eg��@FG`�N��7���_!��*Q��FBĉ��Uog�)�ۑ�ȑ�����NR��s""�D)sY  Q�'��BI��9}�U�!�t?_	R߿���y�@'gM5&I�O�I]#-=��.���F�jr��9l9i��|͑�=��תH��'U4�K3U"�� ���ϲ��$����t��s/�Y��M/�5�k�S�f}}�����eh0ˏ��'�s��#x����UFY��U������h/����dl���K7����Ǚ��0�|c	y����![[lc��s u$V#��������`���	�Ч^]�-��Uu[$.�����U�M���y�6���tÊ5G��e�]���?@�!9aQm�4� �D�@�ƋH Z�PL�F4-�\�$�L���E�3[Ƕ܋%5�f��V����5�M~�,3,��R u	n��ST���$�G&͝�̚��M�"<6L�Kؽ��|�0�*��|��  �A]�3$���|sGwavk
��Xϗ�=��8�S����_ᘒw8�dl�V�ꋳ	�*�Wl��<��?J/u����f��$��8��(��Y�SV�T�{>��YA���R�=��Z<�����'E�!����"�O��IZZ�2GqC6�j%�u�h��o?�_8��	xg��2�j��/��^|�8�EU�Ȫ���r��|���u�}Q�&?��LW��`�o2�So���1Q
����fB���7�?��"xe��=.*=��Ͷm�B��2�Q�%?�tӱq��Ć���o�|8,�Dq[j�y�L]�)�HQ��H6�M�"JU�2��<������o߽��X�T�мT2�"-"wn��}X��]Q��yHEU�|����<m ���aj�Bq'�(d�$��n��C�h�x�+�m��@�Җk�V���$t1���v������&q�搮[Q�ټ���$u�)��wGA�?�<L������O��"R��q��ƞ���Y�"R65*QU�������@Z���l�7;5��5�.X�~�Ë���z���U,��"RÊw�e`�T��jvju �Dq�U�:X+5�AFI��O�o����$��.J�&(m2P}l�F&�o�+E���M���r֚pum����vé���>�\�X��dPSo>X�Q�^�������U:�nl�ݮx���Cᒏ�6�4����8�iQP�"�	�vU'���͊8�*������^�G���0��f�����W�mj�q��^g��in&i��c$C>㽌��E�}�o\�++S@�c��b1�ۜ���㕧�����`J�'� ��S���\otX�l�!�$�G!��A$�nL���2A��3�e\}�B�Y����9J�/u�|�m��~6����'�I���I�N��g����*KU�Q�Q�&���@��h���n�
����S�r�-��8��^U5��ݞ�W�Z,�@�"-��u����fŪ�.l��$�|��xu�'#���>H����x����*���B�3<���ѹj\����UZ6Q�y��]��A,�������_9�4���=��C���xa	v`�5WVXĪ,rH���A�6��[�"n��I�4��:��V��~�d:��*�6Z��!�R�@*V�驠�|�|z�lLķ,�Y�\6�8kƄ-J*��~ʎE =�/C���Y��[�Oޣ��Ɖ��������\Ԕu�ꋆ�ʷuco`��S5�.������m� 7k0�~x)����a�_��	>-�c�V���k����u݊�ծ�"�w�
s
pi�ѐ҃�b�Е��G'a�e������x��#��_�B����rSWs���>!��2��Рce��0�����[]������E�|�o��F�c�'�:^���֣ƃZ���蛍�й��ā�'�r��ͤ�Qe }/�����<�����=ɚ6ߎ#^K��<�>BP�����@\v�Q�V4xK��^��س�[U���#��"�K[a�P��*�L~m8Z�h��8(~��q���?\)��\?���4��A��:&��1�E�/���i�9K&ӳ��F���G��c�����epl��q��x�[Y�fMp��
g�J�+�MD�F��?�� �b�H��������1{ �Ia	"	3�Ŭ:�HN���3JW��)o��m_a���@�0�ָ��.`�@�"���8YD���͗�h>����a�����f:w�t5X���X�۬uV�M>���S��FÚ3��*��p������B�q�0V�o���K�t����:�*Ys�ww��>_ܝ��I<w�%��tl�����9z��?�������:��ڢn�����2��\��ʄO���m��78r�D����mpS�P~ye(��D�����r۸�j]F�D|5����z��,��rϓ���я�~���{�W�&U��]�뉴���	�(�*��we�m�S�b�@���.�d�<�ԇ.O >�\�!(A��p`��:��ۢ)���-�(3�Q*\%6��_B�tj�Fl����YD

=y܃K���k�ܚ,M��s%�j�o
S�=��8�|����/�@���}>��;�'�cE�7>�B^�ʘ��fQR�_�O���`�Wѿ���L�� ��pvС@���%��!^�m�nE~��, �\��za��D�EmB7 ��Vm��|�e}(0l!W�s0�U��"��:*�ض�
�R`ZY�|��U�O�B�p{�ލ�h"F����>V1Non��IѤ)�
���zzֽ�,m���h�蹗�B��~�P�~���
L��&(��9��I��u���n��e�E����Ð�
�yP��7�S����zh��v��Hj�;���ǋ�����l�o��^���
-udf}R�M+&��x;�[��$�js�\�����~ER�ˬ�厳�{Q`E�E��yO���@�ګʰ@�H�Js<�D�y/���=��x	��@n^�J��q�x�Jޡ��z�*�K�v�<}J�p��=�.�X��6���I�w�,	���E�lZ��t�x�2��
p����XU���H0w�"�|Z�,�Q�b�z7���n�ϧ�?��?���nP�V*�>2b�'�qe	�K���uR|Ida,�?T �<��y)^�N�˫�y.�ߞ�������\��܋�]-<c��U���(��}���2���|�OX��lO'y���:�Y�p�p�Ŗ"3�ޑT�Z�*(��v8����(��Ge��    D���_C��@���1A��@� ��1�xNG�ZTQmL��ee�u��d!�	>� �S���	��&�NBD��� ��+�>j4`�JV9e����j#T�g�J���=p����*W�ރr�V(�8̚=�E�'f�s�һ9��Is'&eQ~[���%��1�����۲*�+����B���L�_ϗ#d8�2v���/"T1�W]�g�,���T٢��[�;�E.SߚF�[����"�5£�{\Q�$?\U��
	M�~�T��3�ğ��TF%
� �D\�?�)]�gY�:&���}S�^S�Q:�J���$lʳ����wv3G��P�&�,�S�&�N"�lr��:�J��p;���4BQ�H>��(k�����oX,i?6�(I�3�h0���� Z�CQ�o�zٮ�Ua�N�M�����cugl����?-3̇���뛃o���کD�p 4K��$���E�LU�+劕ݪ���*;��%��� Q�� ��=�>�A�'�A�0�C�����"~���[���Z���a�M�����E-�����P�iNĮH1���)�ԅ��y�O,��OW�GlCL�d,m�Ԝ�m
��}��X-e`�V��_&��ƊΥ��6˓�4d�E��}�0��W͉0���Qgc)W��J5�,([����
��4��j�
��S�E��Q�DC���C %ܞ���tf7�[˲f�\����߸�|44�)Z���G.�k"W&_O�G"WA��jz����h�	�/ ��^� /CN��ctBr�Y%q����2��B��5������Kh���$NԲE٩ʵUp�0,b��)�mdd����cSu�*�*�
�V�B5H�I�@h�H�o�ţ��ʒ�,�Z�(�
Ց���f��WD�,3��WY��Q�b�n~t$��'���\��麨� �nj�*�P�op캫�,�@�:BRiǂ���L-O4��>��,U�n�@8�y��жn��u����AtU�����>�'R������*��J�����&D�ħ�b�?�U��1	ĴKթ��oΘ�=�0��|=qj0��qG.������"��3�:�M+�L�j������!-sk�.����u����C
A�pHm�8�P���j�:������o{��V��h�����ϲ¼R�-�������*��=�2�`؋��(~��v#r�dwxoGZ��gr���}�'�+�%1�$��B�3���!�L*|�'5�ִ+jAZ�Jx�4y���~�(	OW֪o4�ގ�@�t�4A0T̕x�!������g�'a���"P���6z=a�NBKO���?A�����4�u�$s,�H@8���H�}��E���#�XA��|���?(T��D a�
�L�'d%�A�#��S��t;��(�9��Xb�vf+:.y橅�T�e��
�#ZOhťq�g4��g���o�Z�?U��6l�DX�
}(�iZ����~��QA����?�e�\YE�[8�wQ�uf��aE�m]m�冬?�9G��L+��Gr/���[�v���2�%b
�DTi��Lt�su�lx-���Q>�}��0� ��GU�r��l~bRe�mnP�˗���Rd\��������m𢛤�T��:EE\@E��WYco�|%�!R���]��ϕ���u���la|���k,��I����e>G��*�j���_du���]>☪�w���� �'��x.�Q�P����'
�'�@�#P��I�<�y��:�l4:Ne\���宰:^�������Ӹ�R�}�w�����ڻ��V^���9�^.�A�R2��Q�y��5V��EWU]kV͢6&�j���^�s��IF�j(�I�/�P�Ŗ���w9���lV�l��CTViB��v�E���!���`���r�1p ���JM���ǠV��_�/4�J�L�,�u�f�Y�����4�χMv�&4ƜD�1Ÿ1����]�Xs��('��c���EP<���4yY�"�"`��E��u�����̒[�Fu�7�����ȅ���Y��M�榊�⏦�\�M�b=�U>�h�������F����W ��� A��hc̔u^� 9/���MV2x���X����f݊R��F�IQ$*O�;=��|Ͱg���������0���v�>��;q��P>U�2�mmj[��6�ϲ��!jfK;�2�K8���I�mΥY0Om����NH��=b�97�@�������ĕT��Ӭ��IW<�.��Ua�
,�A����E��ʜ݈���;ͪС,� �*���W]U�(l����CW%??`PHʺp���Q�S�;������"�G �n��"�ǧ>��_0k�Ї����qi��b�:_��_߄��N>*����
YD4�&=�f��z�>�<Ly
��W��Y��k��KH���|�������""5��i�G��uW�PQc��^�V�+S���ޞ��,/¾�pt:�(W��.�0cR��r�'	B*d�})����>�UE�r4�.]�ک#!>O��O"�6M�e�~���[���$��N�;�J���؟H=Τ�HVU�8}�&�����-=����M��Å@�?�v��]�P�e���՛�$�*At��J>@g\�`��f�8�=q�IM�g(��'\��T������L  ��������VG&��!}[6�����TP�l~#�@P��*����AWp�APb���8�G/����t�>�)z{�[b�xG��F��eZ�؂���R�+e��*����ط�V��2��h��v$��<7}�F�|E�CU �74��������	�\�dc��@+�>?�z��5�P�K�~��"�n�p�6o�h��)���.1�gEf�����"ǩaplIX�=��V+�N�gG
9� ��Je>��=u���W��ۆ��˱�D�M!���䫤1J��s	ü�P���b��0��/}������h$���6u���&�'7O~�^TϋO�<���.#�H�-�2��Et�@N 4�NQ��=@h��z-��|��2��Bo�UN�MWt:yQօv:e���h(�F2��5cP�y�;Mڇ��=I�ՄE��º��x@�έxE�©,��
'������ ^��+�xz��5I��u�e��w�Gxr� X�2���\��î׵*�"��Z\��HO��R�b跂�{���I�F�Y8��yY����㊅�mQ��)�&��ƧR	�@��{F1L'��5<./�~]�rL!�?v<bT|Vwl}C�4ii�J�����.�Ê��o/��:�����b��V"�B�����A�f1��/Y&�e��-�Z0ƛ�׮Ϻ��0Uy�B�hG:�p �k<I�]�=@v���f/4�E����^	�ȢM�h�u�[�7��+�;��%���и�RG4���;o^8o|<����n��+���V�c�KXh��.CZY:#D\FSϩ[[�+�D]��Y�4 �G�#�K���F&y���{�s�z�}F��� St�f�_�|:�ؓ��Í�y���<�"��������o�ۙf�0�]aCx��t����&;� �R���z0����5�'^o���%> ����&OF6[LJo�A;I'�!B!q���e��r_t�=V؄��/X"����Εq��t"�>/��[�`|=�_gJ���Q| b�C�h0�O�l�"�ߏ:W�������e ]����8����K��aԄbJl_0d�&���&{�y������\^G]��k�l���a)�:�#V��/��?#_jb��lf��#t�����)@Pb����+�$��	�o@���pGYA�m�"5����y�Mm���`�a��A���j���� ��b���x� �Kď6��m�"Uy����������hn��2nO2��=e�� +L�N�L/���"��ed��h^t������(���0�X�B�A�e�Tk�w�l���a���XP#2J�ȿ&�?��bd�~�,KE����[��X��z��,�4lD�K��    ���Y�s�$1q$�jY�;\��$�i�ɉ�is� .��V�}�=Z:����i7K�B��E��'oŉŷ�٥J�?�	��כ��N�RQzl�ô�=>��O�b���Y���1+�h�/k��^.*�jh�|1ZD�&n,��GY����Ղ�Vk,s���!���"� ����CW���nE]�NU�'��[1�/㦾#���z�>��2H��e�,m m�r�1��,൪B��:n�������rܔ��W���q{Un���)�a!	k1���Z��ExkSD�ǣ���������B�U����g0��q� �WcDQ�Èqs���.��������˸��x�`v;tfEU��*TɕI~�;*����`z��7�M얷�&c�|�8]�@��W5�}�ā�$ݪ~xPy"�[a���:�KE�ES�C��H/PC�U���x3Ͱ}��EĮ)���;��3�+�ܿ��](|�e<�|��ݞ:J`Wµ��������p��߀>�ܻQ�S]�`ǾV���~��F�[��>4�A��������`2`"���rO����"Jy���z�\���v_��u��\�o��4��\ 9L��Q��)͓`�1c��(�=~q+�<�̑����LӤ�������N}�&�	U�K�с�\�~��u8E�+��4g(onp���D�b1����	�W�R2g�+4dJcԒ��}��m^�sH�Tn;Lc ����7pJ�@�}Ph٣��g�<z bEgIĿ7��R���z�;В�d����v����[�@�A�'П;bB�Y;�Sb� ��Ӑ��^�3�H41U�H�<�����
3�����̿�8��l��?ȯld9�����!��IKF�SG]�?H�
-����< tRp��:�:�FE>b3�g֔9�ꈠ��6�^S;Ê��3M-�IA�1�ψ~��q��q�*�tי����H��Z��x������İ�i4��@��A���������EѿRзX������z�'�槾R�����	h&` 7��V,PCfg:b$wl~ov,f��!��!Z��b�lB�z����9��)L���*�iѹ��%�:Y��@�ԟou��e�ͯh9��UE�mJ�pd���͆��I�ݸcX���twA��W���Kt�Zs�E��/ȷct(�)5��0����"4����2��n{����.���O��eB�f���x�Z�n�W���|��8�`ߕָ�ĝ]�Զ�W̮A���{{{��0�Ch�+oft����yfr�/�KW� {�.�n�����Ҥ�߀�J~��E<���N���U�*��1��ŢyIv7)���f�7YZ��/��\Y�X������J���8ƳGΚ7���ch63��Qov���lf�/'_���(I�;����`��m~���Ӵ����� -�9������3~���2���QX/�?&�5`����ȍ��<_gX���(��C(ھk������8��KRU��x���d8ۋtý��Q!��	)�	���\f���W:�n�&]��7E:�Zk�ku�i��]��x���&O_��ʐu_`�r��?�E�r[�q]�DMYv���aJ�5h.�@\d�Q��(H�W����Ӽ����*��*\���L�nL��+�e��x�4�<R��D���<��d� ��ڶ}�O�(W`?��riB���4M#�ģ	�4uݭ�ř*�A
�fA���b�:b�U�l6rVK2�v9,4U�;���fR�8 �n�/je��<�(�3Si
G1R��N�����7��vд|�� � ��T�a���R��P7�/8�-���g��+X~�$�E���Kw�L?շJ��Ff���E�l�����Υ���Ο�O�3a[n�䗣���T�@�,���D"啀���"sY�� ��q)�� �M�e���J�3e�Q}ѡ�E�ا�>�h����V�J�2��QE[x7�3������0İU�a���7_�d�5g�Ӟ������!1z}.�U�2�y��bmVt+�b��?)ڸ�:�cF:��y��ٜ߉T��;a���9�^,/3:%FD�G{�ۼk����!-���%���M Q�x7�hw�$�sϪ�s5�֝��,6"�3z���.�F���4�P��<|�Ѥl�x�j!�>O�p�f��c���4���~�RC��S�"���	n��Y��{7�j�`|H�:�����o���F6�Ң`��ֆ�ϟ¦B㪋 Y��GY%C�8�EY��4�h)�-+��XZ�ՈY�.y{��X ��
��(W��7w��z
h���ʍ��ѕ����}]��A�a�0nY�<��m>�����T�*5�¥AxC�%T��G���!(Qj`�,E���..x�@g8c�������+6�UU�A��e>'��X@�D�ǌ��`��M�8b��t|�E�Ldg5.k_*�U��\d�F��g���<=��^*W�V�a4	j�{���֋�ԫ�m�<X��������}W��	�u`�:���A �;�N�'	�C��4 ~��)Z��`��6~d5���-_����q4F|�b���&���P��U�������i�$Ba�ˢ:��`�J�E�\��Ȳv���m�����t��t���n�A�Ò���۹r��UQ\L��jC͛��%�y봨��M�0����:��]�����.�Ub�!pr�T�F�z��b��`ei�8��e��+���$��p?:q�vgab�$�ȍ��єm�*Ggmvޥy�Bj�G��J��M>�|<���Ϝ8��7HGA8o5��=EZnsw��[s�n�By�ΡLwJ��蠳s������z�O��)�e�xi��(~/;�ɢ���nG���B]�e����m���u�v+�e�����=]��"�)*9ּ�#�tw�mǙ�1�0�*p�#��b�S���M���*k[�W�LƎ����.���z50����{5�1,���*2��N�m��pg��
C#_Ы�i�����)d�A���H�6g_J@��RR!O;�qT���,�13[�{1�����_�i�����xAP+����!8`eG���\�k��W���~����%g���T�:_�@z/7�L�Z��F(��^��|��@D�죚#���|\���k���,D�uU�O����ƅg�S�Ik?�4�|�Α!܃1.$�v���=������aF��Ek��:n{���\n����p���L�;�{�>��Q2YR����;��]�v:��'�}=��̽R	�I�v1����!�$tn�%E���ő�H������*J�õ�A��e�k+�E�uGS��ڴ[�
kM��M�~WF0yUe�A�L�c����$���� M����,p����0�+Ub躲]Q��4�U?�N]�k�s��T��^Yח�P6�LVEF*m�<NS�uՊɑ��n����(z
����R��7�ߤ�P�0e���m.Jc���4��`B�kI��6@��<�E'l�I����}� b��1 ����M��8C��f�kq��a�>���s#s
�(qUO6"r���t�J}�xR����hn����uO������0�{�~y�nO��%=��C�g��h�Q�?ik��Cb\cJ	�o|/�B0��-m��iwU�^�������i]�β�=BG0]xF��7!=�P����c�F�ElSӮP{����,O>��G_EO��ۥ��ሗ�C]�� ��bs���7�Y�֗m�m�n��m�0 �%�[IAw�VD��i�3���z��Ef�薨a�fj��H؊0�_�uV&��e�5�����R̑�A�\@�|��ǎ�#�rf��Q�}E.�������M<N�/[VS�$~G�$�z��ooo-������=� b�.cH̪�9ԡ4vB��#;�Ѱ�9�#��w(�4!�j�L�y^z����Gշ��]�5[[�8��)���p�U��O �u�Bt���TE���%c����/#�ߔ��8�Rc�z�Eh���Ve�FV�����u���Pl    ]�uH�u��a��U�j�./�&=I����Ŵ�q�����_��U��lmoW�n["E��&#���;Z�i����3�4O��iLq�y�lf��)�
~�d����uE���㒉�M4�Zb��D�1R�fTbU`��E�\���.��O,�-8;��˥E�2�u�&�����z�v��X�t�n��A)O���_��3�y�ܜ.�iP�ڧ�����r.ͳ��=�����ۢ^A�qY��@&�q[�fvĠ!��|\�[�H�t����x�\m����3E���o�bŁ��X�V��Fa͸�U�	�Q&���xQ_J6a��8!V9���y^�t�ѧ�YQl�"w�.�Y׳�S�K�Oo6��u�zƌ��x�����{q�%�J���Q����Gu�"s��[��p�+H@��)3�2��**�^�[�Vv�'���z����N�S�bCj�9���l+^���M8�&�]vA�6�x��=!,p2�|��i�x�c�2��GK�E�ʢ��n��%c���+TD$���+$�Gpڷ�a �c�Q&�1���ШD�#�fi8ka6�w����+L��1�j��y���<�M4�6� %��x���XYQ��u��%��j�Eϻ�KΔ��LJ�����z�BKԍ󵯽��f��@w�65�UE�G��IPJ}1�o��0��]ĮJ��E��F{�L�vE�*_Gh� 2���aV�(v�L������2D����E�<�U֬��:�w_&?5�i��R���>���0S�R��h�-�b,`�jf�:���j��W}k�D�i�dMhYz>q�C(<��r��˵�*�Lk�E����W�����B#��<בh�'����
��2���m~�Rx�v>�KJ��Y�V��m���_�S�l�ӎ�H~a�>�	�n�Ey�����9k����E����V �G��D/��tk.#�@�t�#���a�@��?Z����Ԯ�G�e��q0�7�Ys�-B�YW`��w}73#D���&��7���m��L�@��16�t�[��6Ed�z4!��M�͂C�/�*Y��q�p������G�{��}���4��ޟ/��E�'�6�n0|i'<y�D�kX���-#�{G�a��mݗ+��:��:!Z�ЇQǎH�S���q��\�ַ�����W�Y�n��ņГO�ѕ�Q� ��W�UD*^�׆^�g�W"��U�� �5��䙬T|��������Eۃ�l��M�(�>����UP�xD�����r=�D�J8K*�/���B"��F\Ҥ�Њ��	Px�C�z�y��t�v�-�0�:)
h�:����06���i>�ck�������w�PU�[ȠTzlm�E*�3�Eݽ?�=�L[>
K���ĕ"h��n)/K H	WjF��ԟ����ߙh��������`Vj�~=��h&�t�(0��O8�](���q8>��-�
��(v;���%!�N0��ߞ���J$�ӟ���;0��������x����Ƽ/��;�%�����R��"~�?,��ZhO������Rm��J��M�5�gy����������!�!0@�dL"��(H;�(_�����,+_�Rߛ���-7Ao�.�����.����'�
���͉R�z��O*������L���s9��_0�L���2�[uF[�C^����-R 0�{{w�vo���ə@E���t�;�у� Dt}UF��6��r.6�6^4��V��R����!},�u+^�#�yf���� f}�ny���Y�3�9�۴X�J�"���(J����N3ۖ{��_�����w���`����� o����.�"�e*��T�]�!k�rE^�YX���/�'ôo(V�z�����,F%��N�!�H�_ƫʋ�:��&�C^��4y�˥Iކ��/��"�]d<T4��P��͛1D����J>���ۊ�¶�#�D��D
��X�0w�ǅ?h;(N-�����m�Uu��c(�,[Q�UE�j�V��?Axx ��?�윦�W�-e���k����/3@�gE\Xm��P�u���U�t!dX�ɬ}$�H�4���c�� uԄF8(��N���nfB*L%�J+��l]eq�f���vÊ���!�>K����N}�kA�c̹����7���H���/��GN�}_xVcz�XD���b�,�p`�\kVT+6zz�I�p�	��|�A-�+�A������?�wP��Z�|"1NaE�s~=���~c�m5��{gQ[����A9�V��I?��0�5Y�I�_2�j}ɞ�K�E��%-6"ז��"��	�|�N&_���S~kPO�Z��M�Z�.+���3N�[���Q�ήǋ
�b@�K����|��D^��cP��[c����'�ƈe��W�%�xo/z�� 6ݏf��T!�u��q�w{өZX�7��s)���.��ڀmZ3@4Eӄ[q��'���E��u���#�v��$(�"CO��fY�.���r����U�S���.��O�iPG� �l�^`�!@n��'L�9���oxUj�����qM3"��:��n�fV�jS$�u�6�J?砐��{��M��h�|9�CtXfQ��%���O�����k�YfW���sŲ@%1$�c��v���/.����8/G������ݫ�0�a=\��q��*.����l�j�"�٤�bL��s�f�8���UDH�?�^�l�n����������s�)3�?�t	V��<8̅�$�^��n��Q��Ѩ�Qi����_�����::�O�G)����~^���$�ë:���p�}O�r؈�f�l���ݨ	1�j؞�o$��D3��3�:��d�D�����M/I�k�h	8���r��k���c���s\�	X�_�0��y~�m���wF͊�k�2<�U�YP�ǻ��q`8<"��i�7�X�d���r;Gd_�u�1�b�� E�2����qњ����4��M}��,0v��	eV�;"q����ݟDJ��k`�p�F{��f1;���YwMXq�۝�0W�0���&�RIΖ��f2�˨���W��B��&?��u�a\�+���Q�!j�~?�mò�{/:���B_�a�;���O6x�XG��y<�2��j>ElƇޚײL��լ���k�˖�6�l��_�_P�5x�(�Ҍ(qDv��L/H Y��\�sa���o����k=	�����as�����,?q�����K�Ghk��'�'R;/�
C/$�Q���������nL��X�K�.���3�?�&K�
�k��Rh<ڂu�{�6��.��Ͼ�� ��i���'�(�U�Wq��DǺ4[����(���jصɓ����.�Gج����G�xJE��Pw~�B'�3�����_�xN�̔q���ƒ]��]��>�\�����1���{L��DL�фt�*]�|9a�Ș�pg�#C;bma���u'���6��)�T�XS�׈*༅*��=�	S���*�SzA�I%�����?�BG�@�\�8�p,�r�M;�)�<2�0M�K˪�#Lc}Gm�� � �࿍�\4	�#�/�B�V�cH$tc V�A�L��ک�rCw ����'M!3�i/�ʂ���Yt��)*���B\�?�J�sд�?����TU$�W�_����8S�F����쪊�D�rT����+�T�������m'�����Sα�u|/42`��'Q��@>�?�]�JI�������BM ��T,x�VE�dTQW� 2���L
9�U��A�L�~83H,Р 	���<F����
!�9XH��6z�j�.5��<�6�=ހ�x��R�ME|�Q��Jq8�*W� E���G��y�\.I_�$��Z_��Q3iȏ�L��~@���8�R�2�z��zc?�`��ŠME�\�,���-�bqj��^�K���X�M��&�K�xc��쑞3�����+���EA�%��O�e��{��xؖ�I2U֤6��Sh�K�m�ufSg~�[Ch���G��|��ڎ����h=g���r�[�ά�ș"}��ac���l����K�%�p$u    uPT@ ?�����R<"�����?�Z���D~�#�w��-�͒�ټ�Q�9����z���b����p(Q�yhꂰ��*�i�и����P�YQyX]]$߷�+�^T�ͽ�L 7b)*���ɳ�@I&f�bm�]��f��>�l ;ִ;�6�s=�l�[|�2q���@�O�5&��jn7�"�ʏ&�<5Z�۵��C���EVV��~Ͼȓ 1.u�N�i{qz
O۽�F\H(tW��-���=j���9QN��c�ﻴoM~{�i�V�um�0y���*R�t�c���򼗬�Qg��	��=�=1cDj{�g/�4�����fQ�𖐮=� Ey|�/�0����~������u�D�!�t7�~�=�QR����9+�rR�h}�S1~��C���]y��.�nF7�U��|h����o���c�7u��m�K�6_0Uɋ:k�;Y'�hF�QPsR �b�Q;�La��FvW�VAll�.�LY�rR#c��9Ơ�{O�S�;�v�@��ľ\Ǣw��yK�2BKأӸ�����Ӷ�r�2ץ�	�l<j�n���V�z%�J��B�vD��c�
�sL@=
d��eS*zFDF뜲�*��lUZ��i�~�Sw�NC�*��~g��Hס�� ��"V�Q�L�,w��v�DnҠc�����Մ����.�Q�S��p�Ѡ\�z�b����(��]�:�9κ.	c5U͑5�'����p����R���e�������0v�P�D7���Qׅ<��L��Y� U��E�5[$od��t55�����~<����A�WG�0	��Y���F�.��pꀉo���m��-�7{Tz�5#%ָZ�[��q��Tqx GQQ��sh���u�ƒ�6u<ᝓ�yL�&�l�k"�UCV.ȃ�4����yV�	Q1e���;��g��ك�/"�=��-�b�*U&�̴����=?q��g��h�A'T�
�z'��5�;�g�i��j����P��[p�&[/HiMU{6��5�V)XWv_�����s=�F��2�;�Ȗ�,<�!�qܔ�9�j��m`*�X���v9�onO|E�Y�b����DA�(��=�2r�����Q޲���I��G
L�����I(G���X��$�E�ڢ�l����e��bY��_�&����[WQ����W��k�& ���b��
��W���/KV�\߁&u��q/�����Я�_����:�#FKmR�E�5��$+�6���Y ���q|#��u�Y0䄤w�EJ��r����%m��=@��I��Et��7��{2"/�b����ˋ��"��T!eM�|�i���gwҎp:P�4��r,���i]~�ώ�V��H��������b��E^�Ud#߼�4Q&�Y��'��p����)���8����Su���.��� ��l��Ҧ�9|�JQxY?��rA���� �������"4К���#��e�e����P��p�����vbP��s%��(�A�ԥ2Jx���F�Ӑ�ytK�xwl�fm� d6�D�|"י�TD�OS���da�BŴ'd�����}	2~q�' ,��Y%���+��Um�7 {�-UQy�BS'𦬰�۵R�� ZϢ$�4Ѕ��,X��rw�w0yf���¸�?�6������a��.d�U��L��tO��y��߯���&��b�zO�A�!4sO!��p0r�7�����9y^K��q�ޟ�&�pE��b�Y'�� 9��RUG�9��.�ԅ�zAhO�W�Z��|���o��\�A�������{����C��߻ջ�ܷ" ��x��@��M:"E� 9�\\�/���*	�^���~B�ǀ�$�j���U�R'w�l�%�}�(b��h.�C��ܗs^�����J �+�]��7��$P��z��%���PV�ԮqL���[��&/�&]PP�Ʀ�:��a�O4�hrwȰ_� ���V�# v �+�o�0ĭ|���������G�V������V�,�����B]rz���Z�+��+�����ޯY�`iyX/h�.��4eY�[���`�:Q�|C�����K�.cP�o�xҼ���<
90�E�w�
�e�&�i��/�u�����e��j@m�"�	��1��\�G5V�F!��Fu�C{�l)y�9�<��U���F�Lӂ��K�h�����"���Y���2�4a����8m�� �	>^;�\�-u��v eY�'I�_��k��b4jG�{��!�|+�-�}�R�l���v4�d�$��y�f(ME����Ҁ�R?%��y�H�=�ݶ�L��?+�ʓ|����0��]�jQ��N�Ƨ뎫6�j#���k����Qٕ�vqg��=#�����t�vR��
��<?��K��|[J[	B���:;��@N}��{]�N��i�@���IV=��� �$��O����N�̢�F�V���U?(f� ��Q��U�	ca8Ё�M'
C�׉�8��I�I��J��LA������[(��Yw?��1.j?ҢJ�mT��o�)s�>�&�ԫ�* �r"�t����f�޵�qA�,�Q�*�>؞���Es� G_����/�#JRk��ڴ�|ePT�B4$�7��غ��FMy[��%��65�gѨ3�Z��ޡ{@1����\�B������Bc%�t���0d�qUM�)mu��4���2�l��:n���T�x<
��~:��{�������Y�r�#�ND��+An�Eˢ(T�Ԧ��Dj{0��	����(��L�=t'�w��4�*����9�ww�Ԯo�eal��k�`��ެ���E���08�P;�ӋELY�id��I76N�6u�`��>Z]�i�R��8���2\p[,b��]R���e���XV>�yLTg���������Ĺ�Eڛl���۝,��Y�_������	�kOTȒ���o�U=�?�+1r�͋��@�>n�M�ȋ|'��S����'��MO������{��%���.4M�G���S�E�KBc�o��"�e�=D�[�����=�����uH!F�
��8���ANaƺ�>V��u(JS�7�_>�e���u����$����W�;m׃+�Y}h����ͿW,�s_V�Ǘ1�-_%���n�B�l\��]��j��e<�<��"c�{YI��� ��S苼���fAlR��X� F�T��o�}���I�K�o)|������:�� ����#�y�ո�Y�e(E�n*�_/	M�%GlV��2K�* jH��	2	���>l��(���AX=©R�u���N�VS$���JM�D�6�)��[0J�NHUQ�'\Ft:֠��h߭~:@�2�yT�of��@SwK���=W��ܖ��͚��u�;�,�t֖�^��7B��o�(m��ؑ~2�~ �x}�<`�x��O�x&J��'���`0A�q��{��ށ3+�W\v|���}B���{�9f��(�������Qʆ�X���9?�����_�^}~t��D�JUF�w�/�8��؄�G�#>Ic��N�����O[��R�Sy��-v?�k�^��+��0�
K��u:�u��(C��V�@��A�@g��g|�� �����Iv�����s^�WY�YW/�++T���Y�H1�������-���u;��\�\fqy�]�1q��M[,�׭���.�<O~ �K)�ߎ,��w��~�[�6ϐE�jT'������0��S���b��@e�2��5/��H���g�����aD�**؈��K����IPU��l��f��t?W,8Y��SȒ��!Њz�.��Ai�y�t�,�c�J֞)W�k	p�R_я�T�%*��v������,�GW\ҏE���!���u����Z���{Q7|��J�Gil�#XU?��O%K��ܭ��~ҟ�����N�+�pV`"��^g����oY�|#{Cd
/��p��R��O*�B��{�qA�	�D7����2����MY�q��X��]YضXp�mѨwx oA.	p�^Za�f\!�    �t<|#��"M2{V&����ټ1��j��{ei��]�����\L�b�B�o�@�(hB�I�'7�u�7.%'w�t�A���h a���_ڪA�����[C�v1@c���elʢ�k>o�R�lXP�W��86�?8�c���rBZwψ�a��Px�,�h�sї�i��;m��.ͦY��4�)�&��0�eX���e�
6(��,x�6[;�<A6����|h�14iU�Ȅ�x����V &�S��)�䗓x�H}!n\b�jb6U�R��LO5C�\��^��
�"�w;wQ7Y�q��
�F.�lZN����Y�ϡ}���.ێ
��Uu4]C1h]�O��ݫp�5)��S"J
���V����F��h�ܲiZ{;���Q��-��{��xx������s��d�c���'�봎[�Eۡ�m].9ry����[�`�Xi7;��2:kWe��kt��\j�1*UQ����<�>�fy'1��"���3E���&�ɏj���-El7 ���~�	�BW:5�SQ4��_vź���5%lU5N�-q𸅈� 㷠��*
��N��=�>T/�/��XK��Y,���m���+�E�a���\�&���XRjD��`r�s�t�ѡ�_pfMYgŠ�@l]��F|������IS��Z^H����Gz�����bJ�2��2^V�'_mK�6�lU��ǣ�����ՠ��R#k��Šejb(�[�Kؕ$���=��w#�ʺ�sŰP����:�ҠFug\&c�d�Z?S f_�\�a��
W���g��ȍ�|[���d�u���HA��pf�KG��E��PLp�ߡ�PD1SG&؆�%y���X�=��NPx��!˹��7�� X�#Fc�@��4읞;S�T��X��o�r�,/x�(}�[�N	:���4s����IH"W�#f٠aw|A�1u���� �����[/xxmV+ޖ)��e{�
��'Η�u}}�!�,<6-��.�����>]�&K�n��,y��<��T��z A@[���n��B�
����hilc��5���VUٶ���45��Z�I\v%Ȗr|{�z��3А2oݭ<�ʛ�S	#�QT�A�'Bĥg�t5]y��@v_]������A�i���N�:9^|i��ۋ��0u��%p�����N��H	�{�����7@����= �,���� ��w�%|�g��\�߼�`�͒���~U�+Z%�Zu<fB�&�nV��R�2�%����l��>���n6�1��R�]�f9!��NU
$m�iz���P��n��������R)0"��=�7�`�L���N�8#Lk���FTs�3�$c*����P�G<6LP6S*��1��h��|YG�sߟ:�tO��?��F�,e����p��$�]�'����W�?��:?_y��iJS�M��z����ua2�"-kƆx/����6gÐ����˙��� UFgܘ��X �j�67u�5�笫���m��e��	��[.���Th�@�O�,�E��;���ű����]�E�T��@3�;W��KP��]�/��=����؃k&��N�	h�'i'I�g�_����X��5��D��vU�K�WUW�T�ɗQ�& H��p魁�K��mP:��`��������=5�#W����U �!�&�<X�i�aA\�-j��*tR�exL�z�H`����븖������<B��V��cb��tSE��.�� 5um����rT�'���c�$~ԛ�=��)}�:k�Y�kc��=�M\M�h�~&��R�5�h-h+H��:~�7�뼶���q묫�(-�)ͺ���)�����G���=���H��D��L��1�$k�>ScIs�9���g��w{	f�c�XU%��.^�O]��%��F������yO����@�1��~�\���D���Tj�rL�jSk��J���SMݚ�"6�
ϕ��`7mv�>Qqw�!Fw�7�\�Ƶހ���-����e���W*o�EҶ�J�����Ӕ��`]B�T�>|z�"�c{�@G�Bp?'��24e'*��A����=���2��-��!�5\���s3[�y�M��:P?��Hg�q����a�dW��K$)�u^;���2�L�JYզ���RWo�O���D���f+q��M�3dR�u"�y	��X阸�F��lȆN�ƷX&Md�cgq"W3���i�a�5*�������C|��xQ;�i`�A]�YTM.��km5�>�no\��\Upߚ,Q`��x�%Q�NH�&����jA8��P!��$lk�l�W�W�Y�/9��Ծ�3y��A�Xj�5��e�Q�=j�.ʴXP�6&0L���P������G;Sπ������^\$,Յ}zň�c��k9�A)"���)���������6��Tx��*?�֧�p��^ߙ��M唛<���प
ZY�Ku3����I����A��4ބa�,��~ӽzl�~<q���"��sR�.��Ɋ���A�VSŅU���޴�0��l*�oM�|V���eF��KW ���TtPE�a�=NMq=�d�&��Kܺ7�qO]uey��m\��	/�J�T6�N �D~�
Gn6.�(��x���[��2�AM�^F�T��˭ݳ���"�4��Do=L���V��gϯ�[!��S1�5��������}���A(P��;��������͛)��ɮR9S�`5F���g�� ��i�c�����d�)���5�3�w���\��o����:~cpCbs_.������gG9smb�J�Z��7�c˛����Θ�����TA7^b�qĮ�Ӑ���N���v�Y��Þ�Ԯ�RX��Z��փ`�ܹ�B	p�G����H��+<�v�WB�m,�&�J�xY�q	6���X/0xiʼ��Jc�Q3�j/�©��!$3��o�Kcy�����D�Y�ʬ�J1�=�K�^����_Ï��k��\
&(�Qs��$할ƙ�ׂZ�H�3 ΁��9��LɈk�,��Y0�,�q���������%�u�|�<�����	a@���I �{x�S���,א[��_ak�ὗ'Y�aW L����k pmɚ]�����q�L,�IOw
.�Ђ�׻�L����my�i��ī��b��|PC�P�a��D9>�8R�����2U�?�{?�(��0f��H�Q��q�<2q��������6M0�'����p��5d?��ozZ�"qe���7��,��7un=��Β��vXA�O��Hq֖���DNJ���]��I��3��>�X�.�f���oӲ[�o�+r4��y�����	�8r�
2�㴋B"{�"h�K��+]Eڬ3K�&�*�O:C~���	r0;ѿFҁ�5vG��sOgΤ]ZD�En��e���,�M�	w�&1��+p7ݭa4w���R7�u�@^�D�w'@E���O�0�1��x�1	�._������)�/)��	2�8��V�s̑���:�EF�g��Tꎰ�h��M�ay8���m�O�K	,��*ޭ>`b<
��'�+�^����۩��x���K�$A���:BU_;坢&
o��	Ĳz|z��%�\���\�s�4����m�E3�:�x����j�4m�k��1�ƥ�e_���Ӛ�Ǯ�U�N�w��B\���Ck��zlI��*��֝0 i�!"rLC���B�nZ�z#0Q#D��3B��%OH�(1b1g�{��YdR��I��9o�J�:�y8WRm!<�n�����1-�"N����x=�� jp�'
R���.���ߴg�.� ���1
��h�	�����q���sU@���l˦'5K���>O�z�}y풓ڔƿO&�º�kOt� 
\�n��� �sj-6-�����*�2���m���8�g�=`���|�S'D�Rai^K�|���"�b��s�8H�F,/�&��j�����Eeo�X�V^����az@��x���J;v��ETe��J��hQ�ڍ�D�䡠iy�e�<�O���Ŧ0u�5���/e�LZTy�D�������u�ԱU    ��Afӄ�nn�ѝ�4Y�������l�e�,fe�Ǧ+F���m��Wi�BwT�>DR�A�X�z1,�ݡ�\�:�� ��	��D��Q�7��ɞAL�f�"�Mo4��.l��V�Ա�kQ�2媹����E���2 ��=���C�A��'r��d�k�*��"�������-x�^I���si)���{4;�b��*b��t�N�r�����u\�x�r��=���ÿ���3K��<�M����3��}�w�c<'ٖ�/�է�#PՋR�U��-����Ywܑ$���q}�B׳虪2�m.��R�n6�t��4�*���<�պs����>Ǝ�U(Pڥ��pi:�|�*���	DD��*"~?�]ƌ�1Kh�C�/8�um=*�tv#��*����;߷�#FO���ڀo��?�>��䢊;���ෛn� ���eKv������\�ި����B��!�E���M󢭟�������2������!@�������yz�WڒL�Uƛ*Tńx���G���lV�S\	��'�	�c2��`O�Q���q����d�����F`�(k �U�P �ɍQ��"�`(.�>��q�� R�=�i��J*�+3��u�9?N6�#��~�D������ǩ	�{�$�Is�(��^�M���0�1*��P}����V~���M^5��-E��E�C�&M�K��e�&j�%oA�����t�Ul���EQ��z~����(n��l�&7W�B�&�2�èK���zy �E�ƺ�[
�P���CN�&KˆNn�c4�+��jA̲��M�{R�mϹ�wG�Ȉ��6��ҍ�L�����4�ꂗ�/KMY~=ڲ�)��f�E��|_���:t�1><�B��Ѡ�M0�R��^ ����ݿ���ș�D��Fk�]�K���s�.�먀o��"T����x<��a7��q��X�R��ƴ��'�G�*ysx�
	�(/��	�*(�K���+H]1Ϥ%E+W��8_{w�}x���Z��=����0o�>F���T���/x��?�H��`���;1��b7�R�_�(6�N���C �߫Ŕ�wT���w��o��:s�d<Ά�<R��՞�_T���7��O�����zsW`��?�*�h]�:��%��J�A�0�v���sZWy\�@<G�������>+�����J,B� �?�=��?/�;���	� ����E���̕Ǹ���q� �Pˍ-7���]4.Si��$pK����)P��0؊�1K�X��M������JC}�=`�**�����Ţ,3�����h�,mn��e �j(��"�ϔ�Q�"�R����T�&�x&@OSx�8y������;s�0��K��#�h�;�����TUg��������n�;'U\8o!c�o� �&*'�����K܋�|���"���JC�%_�=��mz|ul_U�FA���J��p��	&r�ba��n]�����
�7i�|���l���$ޭ~#���R@dSń��]�}о;��Ǳ.l�t�I��,(�G�R�I��3�]/)(S@ܤ߭�PXL歮���/�(N:U�
�:nUm�u�`��Y�L~�ʜ������嶈��(�6������P�񭟟�!,��|��=UH1aiF$�RP�#ڌw�z��}��C�"w!��< ��\���CݞN)��?��L�_�8gxs8���5��z#�Iڅ��\ɏ�5�DGG�؇A �c���G��E�AE�b��з~��d�G��P>Ql��?�s�UV[�)F���*�MU/)JmU�]���t^�ꋾ=�)�2^�ӂ�����Ժ��i�*��m4�{�}��9h�B-���}!-��(����V͝y`��	B����m絬���y��>���/��$��ؐ���7J��,Z0�X��c`e�b�Ә�"i�h־m���g�X1�l��$x�9�[�(_��jq��v,�\";W�~�W�����iM��u}��c�U�h�\4�2�"훌i/��'5�+p��4m�g����$���ˁ(��ҡX���j-��T�4񄱳�oUpG}�\5�������G��(�9�E�L��.e�<Ok�J鿭îg1/
��pf	�����޻���ٗd��~���"ϲ�2~�f������UQ�N���ԻC�V'e��Ξ�7H��U�J��mӶ���yU�Z;ĬH�x�	��=�Y�m߻��8um�Q����l�W9AƯOҮ��4���U&�!A�L;.4\�Z����K^hn>��xV����Ū�ý���2�{j�`ɼF�hk��ߢ>I%��z�D��_�� ~�g� �"��{�BX�9�Q���<�>$�������%^/����)}"M��Y{B�!i$x���]cÅI �y�^�_��9>OC��Hb��xЦ�I�(x�֯��(�o]�q�$�(����� ����ȍ�
��]����~mz�+�1-� y��CA�~X��

0�nz��v�Y���1���v �`]�=b�5��F�$�����3F7*��zo�U��;�%pt9(�^��=�  �#��ڲ�$�U�y�i�Yr]	�<��}��2���L�=�����.�=J:(TH�9faj\7�W���\gmkn�Ɋ�x����i��sQ��jv����+�P�����G��� %#��2�ʰ{���v�lu|U�R-��*K�o��,�,�쭸�?��X����X���fق��e]h	��.����.���z�I������i|\ϑE6�F�XW����F���kӐO��^����;~	�����m�r������n��u;�q��
W�q���$p�u����E��AM�'�M�o��*FZX6����$��鰉�-�uN��"�h�w>
�:��Zb��J�k�n�ۻ�=���E�ݠҠZ�������v&`{��-+8�����b��U�W�ث�<U�0������xh��J�Rp����ڰ���q��{�0�ʝX˄zݽ�O� �����&�P��j���w�
��s�'�;�`@<D��1y�����wR�� yί���8i/R����=�����+���5�P� ��*�4BH����J�ƾ����,����!-��!�[T��l�������_����zx�*��OË���0.(<�y��7X񅱅�����@�=�<�u|V�*���#�O[sQm�[�2Xt��R���ؙ:���d�&��享��Q��Nՙ�q=���q3��Bfl�\Z ��c��h��	�N^s}��t��,t�����n�u�߬7n�5��ay�|=�pK���zY &�Y@lUVY�{���ޔf���m�*D�&p���QV�,�#3�Q	I�T<=� 5��s����ҡ]��(SS:͛䃂��3@g�yP�lDM���
*���c(d�&1+�Ҙ���h+�.�u{{r/�:��T��o��y8@�v�.|�#P�x��!d�qԤ�_� u	'�Y̲*/b���JE�Y1��1˫���,�L��.Z^F�}C!c��!��=e?w��+��BK�*���QeQ�jq�y$H���Z��z��;ߊj� ��+����*y�V����EZ���^ƖxX���U��7t��~�2������A�U?�)Iב�4<��3	�w��Ŧ��>́�;(�;�  EE]��2�l�Q�@�{��y��Xh;�V=X(>�P���=��v�r�����)㊦F<c����b�,��j�/��'.q�J�W�ϗ���t��<�������n}�d���g�z�(�q��	�&��g\>�;z-�M�o;n$T��[9�`SPn#b!�߬���\A�>��v��4��=�����g��(���h�+��_]5u�},���-�%G��i�d<�Z����[�r��R��S�Շ1�:��DQ����i�ga5��'�tS�n�[��zAaQW��������܌�eRJ��;�`�!�D��Z6�>C���Q(�~`9f]�idK�hz���=^i���U�M>�P �ϗQ��q�^8�����?����l]    L���Y��Y6i��ʢI�KĹ�\ayq�z���[�9\��?�ʝ��Mm⺼G�Ԧ��T�M�y�M�&?`��u\�ol��C�����A����>��<[c�,�5����S3��O�\̪ڇ-K>n�2�h�f���I�X�i���y��jl�GIT}����W�C���<�o��9���xE�W��Й��:���ڷ�a�W�7.��Y�����0%��8+�2��h�A�o���oA��Y�a�:vW�2T�ZyS)kz�^>"n���v3u����M��k����^�`^��ý�w��x�8ZhiR����k�� �x��I���[D1(%2�LO��X)>��k��U�����R�E���9F_EN��1ê��~ck">OA�7�i���h�/F�G'�~��<s��f�5��~s���ЗE���Q�LӔe��3A僷�ܕ*�g?)�(�C��O�����˯;��	˾@�V̬֚ ̠pc(���Bg�~@�Ee��n�e�,�Y�Fx1x�b	ky¿*r�b����}�W�p�U������ /p���Sf�ɧѥfX�Eng�=���B4Kv{Sg:_�P���{��	6���T��W�<��s؊n��B���%��@Y��>b��w��:[ ���4��wY�<N&g{��(ȯ��i^B檢�Ld��h�Խi�b�]/m�iL�I~��+���Jv��,����������ha�?���F��[�v����*�۬ѯ����̫*���*�E+������W?Ue�p��D�9oZ��2�U��#��/бl��fF��c1��5�,�U��Ȃ��@R}��z+Wi7�`�ɏ�&2b����w����D�]�"�5�F�};����`U�(��lO"g�aށ�D��Nuy1)㓻�?�}���  �u�4n���"�¢-���,�rV֕q�����Ox��[@���S`+�'���� Z<n�l�n4-�D#~K[�id��h�}����cc�o�gPpgWy�tĞ��3� �h�*�'%�����ew�=i\��x�[���m�I����*O�����=q�u�ԏbȵ�iP������
�e���p|�&����C%̐ ���r>�uDpJ�{Ȳr�du�^�E�P߃��e!�@.�����:���G������4?qww�y�3_�&�;��Ot߅���9194^4|%�[��r�f�*��3���B��>����N�H)��W&�<ىN�j���@���T.p�ъ*%�)ډ��;Aep��M���ğݽ�+1E���N�be�4��[0r0e�:;1��u��Q�i����ꭇv���DGG�t�X�ꎳ(�6��ȋ�¶Q���n���>�ЦC�X'?*��vd.f�=I��ʶ�ť�5,W_�dh
�.xc�uL�C`��2�Tfa�yȰ�tWozj� �1���,V�r��*嶇v�.�.4u�Q�U��:��P��C����\���,\�`K�p��E��Jz�]��F��*Mz����ZZ=?�r�b�cG�����^�[���Q����òϑ�@(1��'r�P	�܊������I�`�[�@UBA��Y���M���)4����
&�H�+��I�ȏ��z�^<�[���.�[*Q���U�i.0��m]lG���C�V¨
O�¹U���Q�����`D�_4���e��c��y7�D�q�TP��<`o��H�):�]N�xU��S�N/ �.�&2O ty�+�ߎ_3��+�,�^נ���ʢ�Z����k����ݻ�;�3�U\�@A^$�����l��厹*I$�t(��Q�@8�t
���W���9�dA��XF��z�`z�j.R�w��ˀX��T�Z��H�F��@0��� �i��s�;㣰����Hp����>rIr��aݧ¼��3���x�.6�#t�1�Z_�Ǣ�}{/Zz\-��Rmvl]�P�W��5�_��qo���}uLT�g���Z@@���w���;� �I���$RuZԱ�����+=o�S�,�S�����oW΂Nq��;��G�77�V]LW/�k׵�q{�xn��tX"T���rԔ�Ot�S��ǋo:���W?!��8Q5�_�kШ#�FFo�ȗD���Zs�*���P�*�j5�w�Vlx�Ս���H��m�u�bt�:�<sw���z>xO!߫���,��-��\A��z��:��o���M�Uؖ�-��[Ϸ��}p��=����A�}�q@n���A�Ǜ L5ӖͱKRRW+�e�`}j��ѓ�x�@>v���ݶ{&.Ǔ�] �k����t�#�]�_)&=
-a*�����Ä����]��g�`�)L�����<=�X�n�̲=@+���]c�_}�3�n<K[�E��l�Ee��&��&ۛr�.��IL�|t�m���b���UhWTE�(�v�cy�T�~R�f�"/�����YlA�0�TrcҮ[�]�2�|�c"OȤ@�������	�ﴞ��6 ��٪��^u@�4�[�y��h���G k:h����Un��6��p�@MTF�L���M�|�k�2��3u�8 R����m�z�+�M�-�q��bt��/��t9���
�Nn���Ϛ�?G���s]�2ǽ����P/����;�:�nR\�o{jl����$�u̜ƺ3Y�Z��p�i�ս��f�<�6����!Q��\i�E��K��pkO�!��b�V_9�������(n��9���H� ���W�Q]$?�O$aۢ�-�8��oN8���^)�j?��wvO�������!��+b���z�8�Ms��b�y�`��J6勇zl!i��Nl�ئx��$<6��1��f����Z��[%�f~\�p<�Vv��O�������0�2e�n���y�Y9�`��Tf6+J:�M�N"�4i�hE�vq/�Wz*�T��@���e�ǭ�"6V�͒j�f�V�n��K�pW_,�1`��gJ����N3�i΀^�K�y�jؒE��­�i��ֽ�]���l��9�:��!��^��� g`:y�E(/2�!��Z�ޥҪ5"��~�Y7.������)0�k;������w+���Y�ix9[��	��p�}꺐lj[����M��C{�M�F�1�����Q��aZ/�1�U���rK��KTg�Yp�������ӢH͂��~���ډ~&�4�* wWP�$�>���N���t��!�GI瑴R�D���bv�i�g�cZ�4�n�D0�tMd�~�7Xd���,ɎH#?���Ǌ��J-��BN�ަ�,�~T��H8,ύY�0�����,8WR�N��p!�|��.���DI˙�E�@�y�v���� ���20�EX�Ȧ���5}Zuٰ��W�i���T����rceqPsq��y�3�L籩\�w�//�Y�=�p��<-ݾa��R�$#q�:����-��L�<:��9��Ӏ�,���X.��{�zA�3u�h�lM��=�L�E�)�����F��>�`AV��'\�x'��a;#[k���V��
[��yw�P�m��0>%��a��k~ԧM��gk�U>9��󑉈Fx�!:8	�V���!غ.��P�h��>m�[С"�� �6ɛ�E�������A������HQ�ᗯ�1����"8�i�\QU��n�O�E�.[��mA!G��T'�3- (M��Q�~��uo!d��8d�s�G��f�ɪ".2'�CF��eX�����d�ښ���Gz����<$M�E7��O��j�!���M���z�^�A��H��Q9�����=�/�~u��e{ԤuE����X�}:�]u�l�O��H~Q'�����v��E�cI��?�6f��ݲ����P��bc���j|�Ԕ�ju�����a��.�^�bSv$���]up��>Z�mOb�\��*˔Y󲪋�%h���}_�8�5EUj��T�o�ڹv@)�	�4�"�"'EP��HH+�/������/ ���t�)����>+�l��}�>� �  ��4&��&�g��I�p��[��t�b6k�o�P~�R�������	J,5�� z#��� #��n���4���҂�*�{���V�
�r�D�lG�/����Wyh} }ü��
�;_���\��_n���ޘ��r�CҀ!�U ��0�9����z8>� B� �w"}�^2L�W������;��) o�D�U*e5��ٲ�u�̋�F˶.o�:7.��i���=�Ž�\>�22��LO 5U�̰;t	�6I�(�'ߴ{23�����K�����>,��LY���	�V8��Tp�[{)�����E_�@�H\lWoݽF��|����;6(f�c��QTL������Z��4ɻ��@sH"n���ȿP j�<�&�$��k���Nc�����!��Y�[Wͩ���όDR����q��^��
��ȅȇ?6������*7�����o��k      p      xڋ���� � �      o      xڋ���� � �      T      xڋ���� � �      S   u	  xڍ�ُ�J �癿��̴UPl���*�����`n�bQeQ����=���ڭ���N�Spp�~@���0Ű]�O77dWT�\��n?��,�'^��(����>ه=5���)���1�����7
@�@����4�/<���CL����!��,�S@�<��7�qv��_�<�V�������
\�E{��F�韈�I��_wz|���,-���F���g:��j�R�e]�n��>�<:���7՚gJ�*���b�ArV&y}�������.D�R��'�.Io��
�!~�I������)��2"7 E� �t �zA�3�/�?�ǖD���ԊΎ=a�N�D�g]^�:#Qnv{1	�B�3g2Z,-¬��N�@�z�ON"�[<{����ŷ%/B�Y�I�p�@ð��=�D�s�����I���F�
��RA�e��U�z=;���ƲDA���P��Qq�Κ��_�ڿ�S}�o1�$�b�TQg��~�@�
@`�g8�,��v����iZ�����f!ӈձ:�p�D�?�ا�|%�'V��Q골�^�x��t�o9���Yg���a��zf��h�h�C��i�:�Iݝ�\GS�x#O������V�^��U���.�s�^�]y���-�-��,HE��,Ϫ0OI�<�4C�����v���/3)���-jx������Mz9�$���n*��n��Ӧ����ΕQS��7�Х��=�-������ ����.��ü �c���Dv��ށ#k����`�8�s���E�[�qu�6���Ff� �r��GK~<��wO��yM�n�]�U��,&1okAV> AN�ا	�Խ���puM��;��������HYB�ǰ�,!u��,]39άI�{��A4�3�����cЪ��<{��9ꙇ��b���U)�Ez�B���b�w�DW�^��^�,J1_���G�%��bc��'������R��#��[ϰ��b0�i�<� �B��L3��{�����G�Y�+b����^_bx[���:�/�-3��H��;&�d��Һ���%��B���⦑S��� Z�g� �X��.k������8�]tU�팤@�ؾn���q-3=���''풁��3͇��<� ~��H�r-�L��r�E��C�}:A�3@i�&�m�s�zM��K�N*n��j�۰�)mg� a��^N���;��8��c��wE������ޢi�1�����r��[�e�p�,�,�l���Q��pޮ5���B�\�'�0��0�d�6���$\�;�F��ġ~�۸�^�'�lk\�L4X��eޡ45�ph���3�A��)p�EoQ}�:��h{�K�vv�M�)[X+�ʥ%�����K&���[����凇)�h���:�9�hf簱̭+,���qqV�2���96r֜�\�o�s+N�saU6��W	x�ᾊ���hV�t�8I����ɚ}Ȃmy@|�jȩZ��j��`��8R�t�$����?җ�p����K�Rm��M�*���[5�'% z@ _`���-K����Q>��l;GO��W�$5ϻ�$��6�=f��������Sjm�[F�=��n��♽�S��D�w�&����M���R���?G�8!$�Q������2�&8��T���h��KQ��'E눾�h>�U#��R�'e_y<�,���;�	�?�C$!UEJ�9|�z���wF�A{mY)�iKR��Bo�Q����'��������� E(�aێBݒu��m)��nS���k�p��i��k��_�w6�b����<Ј�n~.��H���%N#�T�Ӝ�_�I��Q�	\5^OJ+C+���PB�=M@��S*��}	�����D��u|�pG��1b>�0`�Ӛ��RwO�v��3ѕ���&����	��<̥���� tzK���x(��z��1ˮ���^�,�2ϗQY�Ez�s��i�U�����f���5pֹ��\���hDX��{}�mPo�9K�j2��&�-�U1+9+m1|-q��B}�m).N���[����ղ���cX=})2� ̡j1�\��x3�$��X䠘�ɦW�������}tn�I|�tډ��D������B�SС����%����;Lq��_i�������|��v��vڝ}vm��'�Q�d���]w��`C��h\�0�P�qn� {B�䠺�w§��������{�_�Q�<�C���OWW��%�n�Dq�cƝaG�K-�an2�����Ƙ�ľI��Q���ͪ�)f}�W_�!� �/��?y�S��GA�sOy��4q1�o���5���v�_is~<8����+a/�+{͢?�ǌb��(���  ����<�'=�<�n��]��������0c�      l   �  xڕ�A��7�����V`�1��:������δ�R�(�%�� vL�A�1��}ޣp��d_�߿�~}>�K��\1���b�ݙ�;�í�f{�u��	M;
8�]Q7]�2�JWa�(�W�\5/�5눊��X:5|���R:T�U�r�N��P*�u�N�Ҕ��� ��F�`�\��"�U_���:H�N��ptT����v���V�����CM�
u���XǼ���K��누�*������C�W����,���̣�肛.*��:�5bu3�*���Ur�b�B�|^�����k[��|�C�,pA���Gj�����	�ox�sE=1����¨b��0�C���*� @cn���I[Q_cg��Je�*�7�:Ը�K�8y'V�t*��m d��Y\��	��Ѝ_5V
������:�,�c[[{�ѫX/�P�N,_�k�ɼ:{�q@E�r;T��U�xs�������;��J�ʳ�}'j L��w��(��)�ވ��|�c`�����|#W��Y#:��^%�:�ѡ�kC*]	;>#��+�Î���+�w��id����Q��sWTΰN�L�	�;��P�X������ܣ��Dc����ZĚ�w�%1Vw즃���S7�;��-�?�������      m   6  xڥ��n����O���χK��f������$�H�����S3�.4�]�6!��|��OMuu��C�js���~���9����MJ��a�g�>�G�����zo���dE����_��t^+|��`T�K��q�|>=���2��om�/�J������ӱNe�e�E�f�t4��)Ř.�٦�n�`�p��R���4n�V�� !�.�\�i�*��MR��<�)ܢ�1��v�b�R���&��
b�m����~���6�<(�t��KM!:��4rKv$�i*QC�<�Iܚ�t��7�{�4lg��4�q02JUH^&!q�q���nW#�v]*��u�HnN���4kD��$4nL^pj���1]jӞ[��Ƞ��B��6M�a���&q���M�"�TЊ���䒕q��҄���i\�T���f�ե�q��6��Yj$o�T�j���iܢ0�9n�c�R�	�LB$� a�m�JU�Sg��6����F3f7�A�1�j+��6���T���m"7Ge2�팃��R���6�\T�j�m�
�B�m
Wj���Rk��T#Jb�m*��60JRUR)<�i܄�Xn'�Wj+��4r6Z��i*A��s��U���X'IJ�`j�
&3W\��G� �*�*���4nHM���l���(Kp\�ido��4�/���Z�b n���'���ܼM${eGj�JűܦqS��C~�v�ə5���6�2���D�֛/��6��C�l�u�@��Ԛ%�m��ZV\�*QJ�̝�-B�y;���w]�5�LB%��nSUjq�U)"��9f6n�Q��>�28�+����:	U%z�r���P)�q;��T+pݦ���b�m�J��6��dwMm붓"w���y,�mY��2	Q�xgX�6�N8nG zT�A#pݦ�!ّئ�$)*�ܦp��I0�m���fzT%!��D��#sI�JʑUo���Ķw6�>�e�v�D��H&!�D��ئq3��,�S��u���6�\kP#n�T��Z�ܦp���q��#�RA��H�Ҧ��$Uŕ�Z$r�������Hu���ݦ��)q��R�e��$n�b;���Ԭ%�m�4R�Ul0��M�F�e\Q��$L��3T�+������MT�^lӸAEV&����݇!��L���:�6I%j��m
�u�X��h�K�½~�H�"�\�JU���6��AWN&o�+��[��
�F��\�MU鮢��6����8���Ի�?��a��$��lr�$�x�x�$4.Tù7�;CMI�]$���#3w�JɫIH�,*hN&���U�Y�
�U)"�57��MT�jy�M�ڐ9W���8ץ͎m���Fj���%i�l���n2>w��jnMB$���ܦ��^]���nQ.��.J�`��b�W��Z��k��*!�m7�9����֥Zܹ$���I�*
/o��U�ƹ77�w�ZG��Tr�<2�!�Tɻ����QW�Y�����K�5pg�4r��MS1��2	�[e��0�m�@�]j���Tr�n oU�H�U�иJ9��6n M]j����d-�q��bjb��AyΝ U��U�R}�)���*�#n�T�� <�I�"mu�s�\��Rm��ئ���!�i*�������nk�eo= ?T�e�%�d����6U�f�}7D��8��m���R}���6����S�*^�Ƌm7��j������V�C�3��n��E���T[��M�)�`�n�8 �.�v�&���#y���S��6�k1Z8�mL��݇�G�u�Tr�i�m�J-�3eDn�2s�V�f����;�Id1���4��M�f�����߭+�rV���i�l%�*^��s'q����۸���Om�33	��0�� �*�x�%i\%�������-�՗���̽�J���ܩ*��f�n�If��R��_]��<�N&�2��J��s���������ݥ���t���4��F��3VY+�r�k��I;C���a�+�֧�ym�k[���K�h^����|<��?�s�N؜o����g>tɬ:����>�a�uz~��ko+�C�d�bB�,���y��� w�ڙo�^6H--]6��4�cy����n�톍���.]M����u:/��F&��2M�x�p���Pv�ez�ּ�6{2*,
肩v��|:v���&X��ُ�
��Yx�y������R�+6�[ӿ��BIa�-u�������yW��������kWn�-������b��r����|Zrí7�zn#|��,[���|})�x�]�!��r�ͷ��T�����Y�{B�ۗ8���[sc��&��8kY;�$9�^�z{ۄ~7Aߟ����-2��p~�=�3�o�y�m��2��c����~λ����u:,�{����O��t��:��_�Ǻ����3���bZ:Kߓև�9������>��G�����٧��<�f'��?Z��������]:�٣:XO?P\𝕠Op��^��3��3v�[ws�=9`q�y�����q��t��v��y�l�1�K��Xft�!�#�uw�:%��ko��V8XM� U��_���~�M�Z%=9��:��WL�s}<N.Kg~�l�PkqG���un����VO������Ϋ����V��=�bT���NO�x�N��ݾ[.�. EgJ���R�����/�ymn%-��t�PU���n-����|kn�L��1B�LRu�/2�����F�K��Td��O/�q)Ş�'l�kk0�9A�����|��ND,I����7�=,O�!�k:{��k�O�̲Kg~똍�=d�*Z�!�p�ݲ���ymm�R��K���[+��+\���K{^ۛ������ uʒ�.'�j;��~�������`2BK����Ç���g$      r   �  xڭ�I����O���h�10�wo8���`�:��ų$R��&���sj��Q�/N�_ �U�:U	���0!~%����d����(���N�/�Gd�?�^�W�?���d���Т@�����XS3�'�51T\S/��5%Kz����MJs\cYg�� �M�W��s��*t�?��Q1�M�zyYwo��"�a2VĞ9ؘD�
�=Cl��6��G���H�6����hҡ��KŶ$n�Ot�]8��M�H��.Y_	�@�Jo�6� W�����%�@�+bK����햄%J����t[+\�T�>���y�0K�@��7)m�%1]r�ؒ|���W.� �Xu��&�7qnJ+dβ
іiȒX%����7�&YD�(��Ҋا?�ױ1��ֱc���Iz��"�R��[q�b�|'V�W�8H��ҵ����w�&�j7q���>�!��kY-\ڊ��v@l�rw�K_#ny��K� q3�;�k�{��sc� l�E��ĳFI'�ئ'��}�<+�_���Ǝ-oOJ4��L��*����g�71��D���?�5g� �"H\��g���1���}��'���8�݂�����R��
����O&�q(�g��@�`��^��8�^�	ME< �d��^�UM���K�x�c���-YF��*B�
��3�x�4NTE�X�z�
"�ܼ��cQ:D<�۱_5�l-���#-,wh�3�[޴�G��1�)�w̚t�8x�bč�@���.�B6�9�q����3��c/F,p0�L�q��Xz#.��8g|ϙBı�8F|��$��D!BK6C�39N�MPh�?TE�?��qB��	y���w�z�l*$���B,�D&
ޕ�������=���<h	�zF��@��"2�Q{;�ǳ���X�_����f�����<"��ܦ$�bO�A�ǈ�� �8%�8qйň�8����+D7�c$D�tbc�U�*��-���@,?��G�Aw#��Yv�c�8D��l��)o�"�ٌ�U(ÆwF�1��T�U�s���Cs��NT� �)Hh���D��%�ur�G����($����XX)N��ǈ��*L�n�8�WĈ����f	�6���Cĺj��b��y�}�X�����%�����}��͋�s�^'|O5���q�x\tBl�v�iC�GvB�Φ:��A�ı�f��y�L�u��1_"�7XT��Y6vnbđ���k��6=�n���Uz9б	ķ��:�l	�y��A�s%ԍ��X^#h����q�<쑼"D�tB�B�A�y1⫂�ǹE�c!/<�Aȃ�c�h"���,L���"�nA�Ȯ[�A���(�&�?�'�����wE��}w���|��Ā�UG)�H����"/��Yo�y�Ա �2�Շ���g뽈�|��O���n�uѡюhm������kcx5��.��YWs����γdE|%�Ġ@xwj,O�8D<�%�M�ĻM\Z]�GM\Z*9���Ⱦob����M܍W)Y��!�R��G�El|�ѽLʏ��rQk+��Z�>1�,������f�;��ˌ�x�ѴARE��wӱ�f����ȋ&X�ƽI啫��W���M|�=b��0*�������c�����W]�>|��M���y_/�<>b��W�~�:�^����>A<`Ѷ��4�w��G�X5����W�� j���ه�>�s�8���`�U�
X��(,�]��j�� KZZؤ�&��7�G@]�m1��������B�/b����y�Z!��yI\ 끍������HВ�G�]���u�<Bx�ġ�W������x����b5#J�y�:�]���G�'����J�R�Q_��+�6��O�)�o��#�Ve���ŋ�c�P���
��yL��m�s^x�ъ�b�`��=]cE<˳���E� N|�Tm��%ε��k�~gļr��)�l���?~��/��EI      q     xڭ��n+7��λ�%�"�}��A�B��s�8�Oݸ�W�n��f ���B�|H��T�zF%� ��9�G�Yi���ݯ�ߟ/'9�v��i��_�|��v<�8����Zm�-9����yʢ�{�?9�Td�����B�B�#�H�K�[>�|:����.�o}�]Ya��8Uq�d�hH�%ک��~-�[�f����I���Ѕ TZ�B��p���*�F�d�̔G�s�K`L��F����]ț
�r��cBm+�*�`&O��?
|�qH��j*AmGcA(PhD��!�T�W��
]�G!VA�ڷSw��*07�;"`e�-Dm�FP<�<$�.�M���^/&�!�aM� ���SekM�&��Ð�H���TKˏB��qD�ҶQ���J�m]�e5���̕X�6lM�!�S��TM���\Ԑ jԛ
!���۹a@ٖ��A��f�DpM�1����sw����6����}�e�5����Ϯ5�y@4�� "$75ų+��}$�&[��9�"�1%�ۖ����t�B���bD禦&vZ5��n�#�.k�[&�ڕ�K�I�mQ��N�!5�<&bD,Q��2�X��bM�������
y"�(K��_�嬬x]c��B�U�Y�CX4KjZ!Ѻ�-JD��`H��4"H&"m���~���(�"j�a��a��6� ��?.�PWުAb����t�o�.�S��A��E=UM@��PL�#��H˶�u�/w/]�zAr�ɰ"�a�Z4K��� ����/�$@m��� E
HC�B�-���r~�CH+�*�\�|�;�qf	N�p�F�����6w����K��`�aD4Y���:�"C�	,��S	�ho���K��A�ܛ�3ɪ�4BRC�� �n�1��[7����%p�����!�'��
�ۋ��.�� �8�l�����>.�օ0�j�Ěn��ę3�ٱp�����!�٘������B01�Z��(`��3� %��%�J��o����;]��@KpZ��/OOO��,�<      e     xڥXKs��];��ew�(����3Uw=�����&6� �����1����H���Ru�{	e�7XkıQ�_�����2�]�SST��>;V�j۝��画�l����� t���[�+�)E� �3��g)5����(e-W����?b����������Uh���G�(|�UM�Y��?|���U�
C�ah�^ͺ��+u���T��:��V���������۰�ܮrۀlS���z�e� r��~�AS�	٬��NP皤uqM�蚓�:��=��}g�P��aY��
��s>�.���u��]��U��B��n>V�.�e*�N�9][�Nz-�"ת�i�����B�;D��. �@$^�����}���T��|*��T�)т��T5�7�����_���|78s���h �A��I$�b��d�)Ng��؜��
��������u�c��]8h�@�1/ޥ$p)���6��ɂ�9yIJ9_+e��Y�-̇��񵽔HDш�3
n��k��~�V���')�d�2)�!�?�(b*ʑ�����ڦjZ*e�����.�%6n�zie�v�܇�%�;���}W�_��M:ǀ#�)1;�Q�&��F`1:�H�&��e����2K¨f8�̏0)���$&�2�)� �X����Y��P�p��6�x���&�(E�{�i�]���`�9]Š��ż|T�\���5&B%�M���BY�y�X�]�;��\�:�����E���A�&����o���П�5���ʹ�s���ʗx�y5����ٴr^M��00��Uդ��#�w�q.'����6��Jm� �a(�}e��!D�+_\Y�+� ەLS�O�0Y��W<���}��b�L��=,S�aws��\��t{أ�>�j�ʸ����V66���r7�Ǟx�-ם���V;�L�L�e�V�DK�a�@��7�<'Á�ǅ���mj�m3_���`���)�K��	Fg8�r���EK{bR�b��єej���������� ;ة�ݺ
=la7~�AW1�M �~�mR[�V��.un��%�{�f@�[�gt��w�/���Z�Z�-���n�P�~	B� ���i#�]Jt���'j�P�+so�����!�m����6@����t��������d�,�4ы?QI����ca��c�U����}��p�*��q}���<�m�o�]�~B�D�GT��q��n�X�ܸ���7�f��Z�����R f�A}�����	a�H����3���%a�a+��%�?��qc�_�ߛ�@�`�YJ�����*�sKt�(����"'@Y���m���Ȋ����X~���9//���Öd߀�-���gv�R8c���TlD�1(�������6``��p��ѩ��*���L�l�l�3�:�M��84���ͱ��p�����bL2�%Ӽ����UM����
������-ﭡQ�!\'	z��_*$O�#�·@�����z��?��V�o�����`i*E7��6b��R��o��"Wv�.�~����ݮ}�ŷ����:C���͉���T�iZ�d=��e*$�xM��*a7J �R�UߓjMܒ�X`�E5����Q�5C�����G�_��-$�j��i��1���N�9�"۵}��2g\<D�0~-�ߩ���&E��s�I�B~�zn�vsԇ���n�C�/{<�;�{�jw�5�-\
�`M㞋9���b�Ŕ���KXw��n�f}�z<��P��f�����4��(2�vVJ�p�~������@�R�     