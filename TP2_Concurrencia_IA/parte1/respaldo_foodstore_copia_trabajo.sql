--
-- PostgreSQL database dump
--

\restrict 5OvlCXLGz6VOIhJ1KUPsHIv7nf2ggTyHrt1zdGM0WxdWPWzJw9ufpswg5XYp9xz

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

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

--
-- Name: estado_pedido_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.estado_pedido_enum AS ENUM (
    'PENDIENTE',
    'EN_PREPARACION',
    'ENTREGADO',
    'CANCELADO'
);


ALTER TYPE public.estado_pedido_enum OWNER TO postgres;

--
-- Name: forma_pago_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);


ALTER TYPE public.forma_pago_enum OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categoria (
    id bigint NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_categoria_nombre_no_vacio CHECK ((TRIM(BOTH FROM nombre) <> ''::text))
);


ALTER TABLE public.categoria OWNER TO postgres;

--
-- Name: TABLE categoria; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.categoria IS 'CategorÃ­as de agrupaciÃ³n de productos del menÃº.';


--
-- Name: COLUMN categoria.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.categoria.id IS 'Identificador numÃ©rico autogenerado (PK).';


--
-- Name: COLUMN categoria.nombre; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.categoria.nombre IS 'Nombre Ãºnico de la categorÃ­a.';


--
-- Name: COLUMN categoria.activo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.categoria.activo IS 'Bandera de baja lÃ³gica para preservar integridad histÃ³rica (R7).';


--
-- Name: categoria_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.categoria ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cliente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cliente (
    id bigint NOT NULL,
    nombre_completo character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    telefono character varying(30),
    direccion character varying(200),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_cliente_email_valido CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT chk_cliente_nombre_no_vacio CHECK ((TRIM(BOTH FROM nombre_completo) <> ''::text))
);


ALTER TABLE public.cliente OWNER TO postgres;

--
-- Name: TABLE cliente; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cliente IS 'InformaciÃ³n de clientes registrados para realizar pedidos.';


--
-- Name: COLUMN cliente.email; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cliente.email IS 'Correo electrÃ³nico Ãºnico que identifica al cliente (R6).';


--
-- Name: cliente_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.cliente ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cliente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: detalle_pedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_pedido (
    id_pedido bigint NOT NULL,
    id_producto bigint NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) GENERATED ALWAYS AS (((cantidad)::numeric * precio_unitario)) STORED,
    CONSTRAINT chk_detalle_cantidad_positiva CHECK ((cantidad > 0)),
    CONSTRAINT chk_detalle_precio_unitario_positivo CHECK ((precio_unitario >= 0.00))
);


ALTER TABLE public.detalle_pedido OWNER TO postgres;

--
-- Name: TABLE detalle_pedido; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.detalle_pedido IS 'LÃ­neas de detalle de cada producto incluido en un pedido.';


--
-- Name: COLUMN detalle_pedido.cantidad; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.detalle_pedido.cantidad IS 'Cantidad de unidades vendidas (debe ser mayor a 0).';


--
-- Name: COLUMN detalle_pedido.precio_unitario; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.detalle_pedido.precio_unitario IS 'Precio unitario histÃ³rico congelado al momento de la venta (R4).';


--
-- Name: COLUMN detalle_pedido.subtotal; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.detalle_pedido.subtotal IS 'Monto total de la lÃ­nea (calculado automÃ¡ticamente y almacenado).';


--
-- Name: pedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedido (
    id bigint NOT NULL,
    id_cliente bigint NOT NULL,
    fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
    forma_pago public.forma_pago_enum NOT NULL,
    estado public.estado_pedido_enum DEFAULT 'PENDIENTE'::public.estado_pedido_enum NOT NULL,
    observaciones text
);


ALTER TABLE public.pedido OWNER TO postgres;

--
-- Name: TABLE pedido; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.pedido IS 'Cabecera de pedidos realizados por los clientes.';


--
-- Name: COLUMN pedido.id_cliente; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.pedido.id_cliente IS 'Cliente que realizÃ³ el pedido (ParticipaciÃ³n Total, R2).';


--
-- Name: COLUMN pedido.forma_pago; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.pedido.forma_pago IS 'Medio de pago utilizado (EFECTIVO, TARJETA, TRANSFERENCIA).';


--
-- Name: pedido_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.pedido ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pedido_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: producto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.producto (
    id bigint NOT NULL,
    id_categoria bigint NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    precio_lista numeric(10,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_producto_nombre_no_vacio CHECK ((TRIM(BOTH FROM nombre) <> ''::text)),
    CONSTRAINT chk_producto_precio_positivo CHECK ((precio_lista >= 0.00)),
    CONSTRAINT chk_producto_stock_no_negativo CHECK ((stock >= 0))
);


ALTER TABLE public.producto OWNER TO postgres;

--
-- Name: TABLE producto; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.producto IS 'CatÃ¡logo de productos a la venta.';


--
-- Name: COLUMN producto.precio_lista; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.producto.precio_lista IS 'Precio actual de lista del producto (no negativo, R5).';


--
-- Name: COLUMN producto.stock; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.producto.stock IS 'Cantidad disponible en stock (no negativo, R5).';


--
-- Name: COLUMN producto.activo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.producto.activo IS 'Marca de baja lÃ³gica (R7).';


--
-- Name: producto_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.producto ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.producto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: categoria; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categoria (id, nombre, descripcion, activo, created_at) FROM stdin;
1	Pizzas	Pizzas artesanales al horno de barro	t	2026-08-25 22:14:54.926473-03
2	Bebidas	Gaseosas, jugos y aguas	t	2026-08-25 22:14:54.926473-03
\.


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cliente (id, nombre_completo, email, telefono, direccion, created_at) FROM stdin;
1	Ana GÃ³mez	ana.gomez@example.com	261-4567890	Av. San MartÃ­n 1234, Mendoza	2026-08-25 22:14:54.933807-03
2	Luis Paz	luis.paz@example.com	261-7890123	Calle Belgrano 456, Godoy Cruz	2026-08-25 22:14:54.933807-03
3	Marta Ruiz	marta.ruiz@example.com	261-1234567	Calle Las Heras 789, Ciudad	2026-08-25 22:14:54.933807-03
\.


--
-- Data for Name: detalle_pedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) FROM stdin;
1	1	2	1000.00
1	3	1	800.00
2	2	1	1500.00
3	1	3	1050.00
4	3	4	800.00
4	2	2	1500.00
5	1	1	1050.00
\.


--
-- Data for Name: pedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pedido (id, id_cliente, fecha_hora, forma_pago, estado, observaciones) FROM stdin;
1	1	2026-03-01 20:30:00-03	EFECTIVO	ENTREGADO	\N
2	2	2026-03-01 21:15:00-03	TARJETA	ENTREGADO	\N
3	1	2026-03-05 21:00:00-03	TRANSFERENCIA	ENTREGADO	\N
4	3	2026-03-06 20:45:00-03	EFECTIVO	ENTREGADO	\N
5	2	2026-03-07 22:00:00-03	TARJETA	ENTREGADO	\N
\.


--
-- Data for Name: producto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.producto (id, id_categoria, nombre, descripcion, precio_lista, stock, activo, created_at) FROM stdin;
1	1	Muzzarella	\N	1050.00	50	t	2026-08-25 22:14:54.939012-03
2	1	Napolitana	\N	1500.00	35	t	2026-08-25 22:14:54.939012-03
3	2	Coca 1.5L	\N	800.00	100	t	2026-08-25 22:14:54.939012-03
\.


--
-- Name: categoria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categoria_id_seq', 2, true);


--
-- Name: cliente_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cliente_id_seq', 3, true);


--
-- Name: pedido_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pedido_id_seq', 5, true);


--
-- Name: producto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.producto_id_seq', 3, true);


--
-- Name: categoria categoria_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_nombre_key UNIQUE (nombre);


--
-- Name: categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id);


--
-- Name: cliente cliente_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_email_key UNIQUE (email);


--
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id);


--
-- Name: pedido pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT pedido_pkey PRIMARY KEY (id);


--
-- Name: detalle_pedido pk_detalle_pedido; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto);


--
-- Name: producto producto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id);


--
-- Name: idx_detalle_pedido_producto_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalle_pedido_producto_id ON public.detalle_pedido USING btree (id_producto);


--
-- Name: idx_pedidos_cliente_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedidos_cliente_id ON public.pedido USING btree (id_cliente);


--
-- Name: idx_productos_categoria_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_productos_categoria_activo ON public.producto USING btree (id_categoria, activo) WHERE (activo = true);


--
-- Name: detalle_pedido fk_detalle_pedido_pedido; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT fk_detalle_pedido_pedido FOREIGN KEY (id_pedido) REFERENCES public.pedido(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: detalle_pedido fk_detalle_pedido_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT fk_detalle_pedido_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: pedido fk_pedido_cliente; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES public.cliente(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: producto fk_producto_categoria; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES public.categoria(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict 5OvlCXLGz6VOIhJ1KUPsHIv7nf2ggTyHrt1zdGM0WxdWPWzJw9ufpswg5XYp9xz

