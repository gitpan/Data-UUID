#if !defined __UUID_H__
#    define  __UUID_H__

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include "md5.h"

#if defined __CYGWIN__
#include <windows.h>
#endif

#if !defined _STDIR
#    define  _STDIR			"/var/tmp"
#endif

#define UUID_STATE			".UUID_STATE"
#define UUID_NODEID			".UUID_NODEID"
#define UUID_STATE_NV_STORE		_STDIR"/"UUID_STATE
#define UUID_NODEID_NV_STORE		_STDIR"/"UUID_NODEID

#define UUIDS_PER_TICK 1024
#define I64(C) C##LL

#define F_BIN 0
#define F_STR 1
#define F_HEX 2
#define F_B64 3

#define CHECK(f1, f2) if (f1 != f2) RETVAL = f1 < f2 ? -1 : 1;

typedef unsigned long      unsigned32;
typedef unsigned short     unsigned16;
typedef unsigned char      unsigned8;
typedef unsigned char      byte;
typedef unsigned long long unsigned64_t;
typedef unsigned64_t       uuid_time_t;

#if defined __CYGWIN__
#define LOCK(f)
#define UNLOCK(f)
#else
#define LOCK(f)		lockf(fileno(f),F_LOCK,0);
#define UNLOCK(f)	lockf(fileno(f),F_ULOCK,0);
#endif

#undef uuid_t

typedef struct _uuid_node_t {
   char nodeID[6];
} uuid_node_t;

typedef struct _uuid_t {
   unsigned32          time_low;
   unsigned16          time_mid;
   unsigned16          time_hi_and_version;
   unsigned8           clock_seq_hi_and_reserved;
   unsigned8           clock_seq_low;
   byte                node[6];
} uuid_t;

typedef struct _uuid_state_t { 
   uuid_time_t ts;
   uuid_node_t node;
   unsigned16  cs;  
} uuid_state_t;

typedef struct _uuid_context_t {
   uuid_state_t state;
   uuid_node_t  nodeid;
   uuid_time_t  next_save;
} uuid_context_t;

int  uuid_create(uuid_t * uuid);
void uuid_create_from_name(
   uuid_t * uuid,
   uuid_t nsid,
   void * name,
   int namelen
);
int  uuid_compare(uuid_t *u1, uuid_t *u2);
static int  read_state(
   unsigned16  *clockseq, 
   uuid_time_t *timestamp,
   uuid_node_t * node
);
static void write_state(
   unsigned16   clockseq, 
   uuid_time_t  timestamp,
   uuid_node_t  node
);
static void format_uuid_v1(
   uuid_t      *uuid, 
   unsigned16   clockseq,
   uuid_time_t  timestamp, 
   uuid_node_t  node
);
static void format_uuid_v3(
   uuid_t      *uuid, 
   unsigned     char hash[16]
);
static void       get_current_time(uuid_time_t * timestamp);
static unsigned16 true_random(void);
static void       get_ieee_node_identifier(uuid_node_t *node);
static void       get_system_time(uuid_time_t *uuid_time);
static void       get_random_info(char seed[16]);

static char   *base64 = 
   "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static unsigned char index64[256] = {
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,62, 255,255,255,63,
   52,53,54,55, 56,57,58,59, 60,61,255,255, 255,254,255,255,
   255, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
   15,16,17,18, 19,20,21,22, 23,24,25,255, 255,255,255,255,
   255,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
   41,42,43,44, 45,46,47,48, 49,50,51,255, 255,255,255,255,

   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
   255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
};
#endif
