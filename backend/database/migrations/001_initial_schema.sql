--
-- PostgreSQL database dump
--

\restrict qL2WcVoJuGTc8zD1mGwSUSuocAB5Owzm945WCbrmDKOetqkj2QaUx3IMtSYAGKL

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    user_id bigint NOT NULL,
    parent_comment_id bigint,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT comments_content_check CHECK ((length(TRIM(BOTH FROM content)) > 0))
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.comments ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: media_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_assets (
    id bigint NOT NULL,
    uploaded_by_user_id bigint NOT NULL,
    media_type character varying(20) NOT NULL,
    processing_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    storage_key text NOT NULL,
    mime_type character varying(100) NOT NULL,
    size_bytes bigint NOT NULL,
    width integer,
    height integer,
    duration_ms bigint,
    checksum_sha256 character varying(64),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT media_duration_check CHECK (((duration_ms IS NULL) OR (duration_ms > 0))),
    CONSTRAINT media_height_check CHECK (((height IS NULL) OR (height > 0))),
    CONSTRAINT media_processing_status_check CHECK (((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'ready'::character varying, 'failed'::character varying, 'quarantined'::character varying])::text[]))),
    CONSTRAINT media_size_check CHECK ((size_bytes > 0)),
    CONSTRAINT media_type_check CHECK (((media_type)::text = ANY ((ARRAY['image'::character varying, 'video'::character varying, 'audio'::character varying])::text[]))),
    CONSTRAINT media_width_check CHECK (((width IS NULL) OR (width > 0)))
);


--
-- Name: media_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.media_assets ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.media_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: post_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_likes (
    post_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: post_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_media (
    post_id bigint NOT NULL,
    media_asset_id bigint NOT NULL,
    sort_order integer NOT NULL,
    alt_text character varying(500),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT post_media_order_check CHECK ((sort_order >= 0))
);


--
-- Name: post_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_stats (
    post_id bigint NOT NULL,
    likes_count bigint DEFAULT 0 NOT NULL,
    comments_count bigint DEFAULT 0 NOT NULL,
    reposts_count bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT post_stats_comments_check CHECK ((comments_count >= 0)),
    CONSTRAINT post_stats_likes_check CHECK ((likes_count >= 0)),
    CONSTRAINT post_stats_reposts_check CHECK ((reposts_count >= 0))
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    content text,
    visibility character varying(20) DEFAULT 'public'::character varying NOT NULL,
    status character varying(20) DEFAULT 'draft'::character varying NOT NULL,
    comments_enabled boolean DEFAULT true NOT NULL,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT posts_content_not_empty CHECK (((content IS NULL) OR (length(TRIM(BOTH FROM content)) > 0))),
    CONSTRAINT posts_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'pending_review'::character varying, 'published'::character varying, 'hidden'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT posts_visibility_check CHECK (((visibility)::text = ANY ((ARRAY['public'::character varying, 'followers'::character varying, 'private'::character varying])::text[])))
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.posts ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username character varying(30) NOT NULL,
    display_name character varying(100) NOT NULL,
    email character varying(254),
    phone_number character varying(20),
    password_hash text,
    bio character varying(500),
    avatar_storage_key text,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    email_verified_at timestamp with time zone,
    phone_verified_at timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT users_display_name_check CHECK ((length(TRIM(BOTH FROM display_name)) > 0)),
    CONSTRAINT users_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'pending_verification'::character varying])::text[]))),
    CONSTRAINT users_username_format_check CHECK (((username)::text ~ '^[A-Za-z0-9_]{3,30}$'::text))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: media_assets media_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT media_assets_pkey PRIMARY KEY (id);


--
-- Name: media_assets media_assets_storage_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT media_assets_storage_key_key UNIQUE (storage_key);


--
-- Name: post_likes post_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id);


--
-- Name: post_media post_media_order_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_order_unique UNIQUE (post_id, sort_order);


--
-- Name: post_media post_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_pkey PRIMARY KEY (post_id, media_asset_id);


--
-- Name: post_stats post_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_stats
    ADD CONSTRAINT post_stats_pkey PRIMARY KEY (post_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: comments_post_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_post_created_idx ON public.comments USING btree (post_id, created_at DESC) WHERE (deleted_at IS NULL);


--
-- Name: comments_user_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_user_created_idx ON public.comments USING btree (user_id, created_at DESC);


--
-- Name: media_assets_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX media_assets_owner_idx ON public.media_assets USING btree (uploaded_by_user_id, created_at DESC);


--
-- Name: media_assets_processing_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX media_assets_processing_idx ON public.media_assets USING btree (processing_status, created_at);


--
-- Name: post_likes_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_likes_user_idx ON public.post_likes USING btree (user_id, created_at DESC);


--
-- Name: post_media_asset_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_media_asset_idx ON public.post_media USING btree (media_asset_id);


--
-- Name: posts_public_feed_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_public_feed_idx ON public.posts USING btree (published_at DESC, id DESC) WHERE (((status)::text = 'published'::text) AND ((visibility)::text = 'public'::text) AND (deleted_at IS NULL));


--
-- Name: posts_user_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_user_created_idx ON public.posts USING btree (user_id, created_at DESC);


--
-- Name: users_email_lower_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_lower_unique ON public.users USING btree (lower((email)::text)) WHERE (email IS NOT NULL);


--
-- Name: users_phone_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_phone_unique ON public.users USING btree (phone_number) WHERE (phone_number IS NOT NULL);


--
-- Name: users_username_lower_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_lower_unique ON public.users USING btree (lower((username)::text));


--
-- Name: comments comments_parent_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_fk FOREIGN KEY (parent_comment_id) REFERENCES public.comments(id) ON DELETE RESTRICT;


--
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: media_assets media_assets_uploaded_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_assets
    ADD CONSTRAINT media_assets_uploaded_by_user_id_fkey FOREIGN KEY (uploaded_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: post_likes post_likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_likes post_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: post_media post_media_media_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_media_asset_id_fkey FOREIGN KEY (media_asset_id) REFERENCES public.media_assets(id) ON DELETE RESTRICT;


--
-- Name: post_media post_media_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_stats post_stats_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_stats
    ADD CONSTRAINT post_stats_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict qL2WcVoJuGTc8zD1mGwSUSuocAB5Owzm945WCbrmDKOetqkj2QaUx3IMtSYAGKL

