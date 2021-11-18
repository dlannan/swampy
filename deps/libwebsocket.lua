local ffi  = require "ffi"

ffi.cdef[[
enum WS_FRAME_STATE {
        sw_start = 0,
        sw_got_two,
        sw_got_short_len,
        sw_got_full_len,
        sw_loaded_mask
};

enum WS_THREAD_TYPE {
	th_onmessage = 0,
	th_onclose = 1,
	th_onopen = 2
};

typedef struct _libwebsock_frame {
        unsigned int fin;
        unsigned int opcode;
        unsigned int mask_offset;
        unsigned int payload_offset;
        unsigned int rawdata_idx;
        unsigned int rawdata_sz;
        unsigned int size;
        unsigned int payload_len_short;
        unsigned int payload_len;
        char *rawdata;
        struct _libwebsock_frame *next_frame;
        struct _libwebsock_frame *prev_frame;
        unsigned char mask[4];
        enum WS_FRAME_STATE state;
} libwebsock_frame;

typedef struct _libwebsock_string {
        char *data;
        int length;
        int idx;
        int data_sz;
} libwebsock_string;

typedef struct _libwebsock_message {
        unsigned int opcode;
        unsigned long long payload_len;
        char *payload;
} libwebsock_message;

typedef struct _libwebsock_close_info {
        unsigned short code;
        char reason[124];
} libwebsock_close_info;

/* Thread identifiers.  The structure of the attribute type is not
   exposed on purpose.  */
typedef unsigned long int pthread_t;

typedef struct __pthread_internal_list
{
  struct __pthread_internal_list *__prev;
  struct __pthread_internal_list *__next;
} __pthread_list_t;

/* Data structures for mutex handling.  The structure of the attribute
   type is not exposed on purpose.  */
typedef union
{
    struct __pthread_mutex_s
    {
        int __lock;
        unsigned int __count;
        int __owner;
        unsigned int __nusers;
        /* KIND must stay at this position in the structure to maintain
            binary compatibility.  */
        int __kind;
        int __spins;
        __pthread_list_t __list;
    } __data;
    char __size[40];
    long int __align;
} pthread_mutex_t;

typedef struct _libwebsock_client_state {
        int sockfd;
        int flags;
        void *data;
        libwebsock_frame *current_frame;
        struct sockaddr_storage *sa;
        struct bufferevent *bev;
        uint64_t *tlist;
        pthread_mutex_t thread_lock;
        int (*onmessage)(struct _libwebsock_client_state *, libwebsock_message *);
        int (*control_callback)(struct _libwebsock_client_state *, libwebsock_frame *);
        int (*onopen)(struct _libwebsock_client_state *);
        int (*onclose)(struct _libwebsock_client_state *);
        int (*onpong)(struct _libwebsock_client_state *);
        uint64_t *ssl;
        libwebsock_close_info *close_info;
        void *ctx;
        struct _libwebsock_client_state *next;
        struct _libwebsock_client_state *prev;
} libwebsock_client_state;

typedef struct _thread_state_wrapper {
	pthread_t thread;
	libwebsock_client_state *state;
} thread_state_wrapper;

typedef struct _libwebsock_context {
        int running;
        int ssl_init;
        int flags;
        int owns_base;
        struct event_base *base;
        int (*onmessage)(libwebsock_client_state *, libwebsock_message *);
        int (*control_callback)(libwebsock_client_state *, libwebsock_frame *);
        int (*onopen)(libwebsock_client_state *);
        int (*onclose)(libwebsock_client_state *);
        int (*onpong)(libwebsock_client_state *);
        libwebsock_client_state *clients_HEAD;
        void *user_data; //context specific user data
} libwebsock_context;

typedef struct _libwebsock_onmessage_wrapper {
  libwebsock_client_state *state;
  libwebsock_message *msg;
} libwebsock_onmessage_wrapper;

typedef struct _libwebsock_fragmented {
        char *send;
        char *queued;
        unsigned int send_len;
        unsigned int queued_len;
        struct _libwebsock_client_state *state;
} libwebsock_fragmented;
typedef struct SSL_CTX SSL_CTX;
typedef struct _libwebsock_ssl_event_data {
        SSL_CTX *ssl_ctx;
        libwebsock_context *ctx;
} libwebsock_ssl_event_data;

int libwebsock_ping(libwebsock_client_state *state);
int libwebsock_close(libwebsock_client_state *state);
int libwebsock_close_with_reason(libwebsock_client_state *state, unsigned short code, const char *reason);
int libwebsock_send_binary(libwebsock_client_state *state, const char *in_data, unsigned int payload_len);
int libwebsock_send_all_text(libwebsock_context *ctx, const char *strdata);
int libwebsock_send_text(libwebsock_client_state *state, const char *strdata);
int libwebsock_send_text_with_length(libwebsock_client_state *state, char *strdata, unsigned int payload_len);
void libwebsock_wait(libwebsock_context *ctx);
void libwebsock_step(libwebsock_context *ctx);
void libwebsock_bind(libwebsock_context *ctx, const char *listen_host, const char *port);
/* void libwebsock_bind_socket(libwebsock_context *ctx, evutil_socket_t sockfd); */
char *libwebsock_version_string(void);
libwebsock_context *libwebsock_init(void);
libwebsock_context *libwebsock_init_flags(int flags);
libwebsock_context *libwebsock_init_base(struct event_base *base, int flags);

void libwebsock_bind_ssl(libwebsock_context *ctx, const char *listen_host, const char *port, const char *keyfile, const char *certfile);
void libwebsock_bind_ssl_real(libwebsock_context *ctx, const char *listen_host, const char *port, const char *keyfile, const char *certfile, const char *chainfile);
    
void usleep( unsigned int tm );
]]

--------------------------------------------------------------------------------
local websocket = ffi.load("websock")


return websocket
