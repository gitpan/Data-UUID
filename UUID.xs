#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "UUID.h"

static  uuid_t NameSpace_DNS = { /* 6ba7b810-9dad-11d1-80b4-00c04fd430c8 */
   0x6ba7b810,
   0x9dad,
   0x11d1,
   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
};

static  uuid_t NameSpace_URL = { /* 6ba7b811-9dad-11d1-80b4-00c04fd430c8 */
   0x6ba7b811,
   0x9dad,
   0x11d1,
   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
};

static  uuid_t NameSpace_OID = { /* 6ba7b812-9dad-11d1-80b4-00c04fd430c8 */
   0x6ba7b812,
   0x9dad,
   0x11d1,
   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
};

uuid_t NameSpace_X500 = { /* 6ba7b814-9dad-11d1-80b4-00c04fd430c8 */
   0x6ba7b814,
   0x9dad,
   0x11d1,
   0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
};

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

void format_uuid_v1(
   uuid_t     *uuid, 
   unsigned16  clock_seq, 
   uuid_time_t timestamp, 
   uuid_node_t node
) {
   uuid->time_low = (unsigned long)(timestamp & 0xFFFFFFFF);
   uuid->time_mid = (unsigned short)((timestamp >> 32) & 0xFFFF);
   uuid->time_hi_and_version = (unsigned short)((timestamp >> 48) &
      0x0FFF);

   uuid->time_hi_and_version |= (1 << 12);
   uuid->clock_seq_low = clock_seq & 0xFF;
   uuid->clock_seq_hi_and_reserved = (clock_seq & 0x3F00) >> 8;
   uuid->clock_seq_hi_and_reserved |= 0x80;
   memcpy(&uuid->node, &node, sizeof uuid->node);
};

void get_current_time(uuid_time_t * timestamp) {
   uuid_time_t        time_now;
   static uuid_time_t time_last;
   static unsigned16  uuids_this_tick;
   static int         inited = 0;

   if (!inited) {
      get_system_time(&time_now);
      uuids_this_tick = UUIDS_PER_TICK;
      inited = 1;
   };
   while (1) {
      get_system_time(&time_now);

      if (time_last != time_now) {
         uuids_this_tick = 0;
         break;
      };
      if (uuids_this_tick < UUIDS_PER_TICK) {
         uuids_this_tick++;
         break;
      };
   };
   *timestamp = time_now + uuids_this_tick;
};

static unsigned16 true_random(void) {
   static int  inited = 0;
   uuid_time_t time_now;

   if (!inited) {
      get_system_time(&time_now);
      time_now = time_now/UUIDS_PER_TICK;
      srand((unsigned int)(((time_now >> 32) ^ time_now)&0xffffffff));
      inited = 1;
    };
    return (rand());
}

void format_uuid_v3(
   uuid_t        *uuid, 
   unsigned char  hash[16]
) {
   memcpy(uuid, hash, sizeof(uuid_t));

   uuid->time_low            = ntohl(uuid->time_low);
   uuid->time_mid            = ntohs(uuid->time_mid);
   uuid->time_hi_and_version = ntohs(uuid->time_hi_and_version);

   uuid->time_hi_and_version &= 0x0FFF;
   uuid->time_hi_and_version |= (3 << 12);
   uuid->clock_seq_hi_and_reserved &= 0x3F;
   uuid->clock_seq_hi_and_reserved |= 0x80;
};

void get_system_time(uuid_time_t *uuid_time) {
   struct timeval tp;

   gettimeofday(&tp, (struct timezone *)0);
   *uuid_time = (tp.tv_sec * 10000000) + (tp.tv_usec * 10) +
      I64(0x01B21DD213814000);
};

void get_random_info(char seed[16]) {
   MD5_CTX c;
   typedef struct {
      long           hostid;
      struct timeval t;
      char           hostname[257];
   } randomness;
   randomness r;

   MD5Init(&c);
   r.hostid = gethostid();
   gettimeofday(&r.t, (struct timezone *)0);
   gethostname(r.hostname, 256);
   MD5Update(&c, (unsigned char*)&r, sizeof(randomness));
   MD5Final(seed, &c);
};

SV* make_ret(const uuid_t u, int type) {
   unsigned char  c1, c2, c3;
   char           buf[BUFSIZ];
   char          *from, *to;
   STRLEN         len;
   int            i;

   memset(buf, 0x00, BUFSIZ);
   switch(type) {
   case F_BIN:
      memcpy(buf, (void*)&u, sizeof(uuid_t));
      len = sizeof(uuid_t);
      break;
   case F_STR:
      sprintf(buf, "%8.8X-%4.4X-%4.4X-%2.2X%2.2X-", u.time_low, u.time_mid,
	 u.time_hi_and_version, u.clock_seq_hi_and_reserved, u.clock_seq_low);
      for(i = 0; i < 6; i++ ) 
	 sprintf(buf+strlen(buf), "%2.2X", u.node[i]);
      len = strlen(buf);
      break;
   case F_HEX:
      sprintf(buf, "0x%8.8X%4.4X%4.4X%2.2X%2.2X", u.time_low, u.time_mid,
	 u.time_hi_and_version, u.clock_seq_hi_and_reserved, u.clock_seq_low);
      for(i = 0; i < 6; i++ ) 
	 sprintf(buf+strlen(buf), "%2.2X", u.node[i]);
      len = strlen(buf);
      break;
   case F_B64:
      from = (unsigned char*)&u; to = buf;
      while (1) {
	 c1    = *from++;
	 *to++ = base64[c1>>2];
	 if (from == ((char*)&u + 16)) {
	    *to++ = base64[(c1 & 0x3) << 4];
	    break;
         }
         c2   = *from++;
	 c3   = *from++;
	 *to++ = base64[((c1 & 0x3) << 4) | ((c2 & 0xF0) >> 4)];
	 *to++ = base64[((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6)];
	 *to++ = base64[c3 & 0x3F];
      }
      len = strlen(buf);
      break;
   default:
      croak("invalid type: %d\n", type);
      break;
   }
   return sv_2mortal(newSVpv(buf,len));
};
      
MODULE = Data::UUID		PACKAGE = Data::UUID		

PROTOTYPES: DISABLE

void
constant(sv,arg)
PREINIT:
   STRLEN  len;
   char   *pv;
INPUT:
   SV   *sv
   char *s = SvPV(sv, len);
   int	 arg
PPCODE:
   pv = 0; len = sizeof(uuid_t);
   if (strEQ(s,"NameSpace_DNS"))
      pv = (char*)&NameSpace_DNS;
   if (strEQ(s,"NameSpace_URL"))
      pv = (char*)&NameSpace_URL;
   if (strEQ(s,"NameSpace_X500"))
      pv = (char*)&NameSpace_X500;
   if (strEQ(s,"NameSpace_OID"))
      pv = (char*)&NameSpace_OID;
   ST(0) = sv_2mortal(newSVpv(pv, len));
   XSRETURN(1);

uuid_context_t*
new(class)
   char *class;
PREINIT:
   FILE        *fd;
   char         seed[16];
   uuid_time_t  timestamp;
CODE:
   Newz(0,RETVAL,1,uuid_context_t);
   if (fd = fopen(UUID_STATE_NV_STORE, "rb")) {
      fread(&(RETVAL->state), sizeof(uuid_state_t), 1, fd);
      fclose(fd);
   }
   if (fd = fopen(UUID_NODEID_NV_STORE, "rb")) {
      fread(&(RETVAL->nodeid), sizeof(uuid_node_t), 1, fd );
      fclose(fd);
   } else {
      get_random_info(seed);
      seed[0] |= 0x80;
      memcpy(&(RETVAL->nodeid), seed, sizeof(uuid_node_t));
      if (fd = fopen(UUID_NODEID_NV_STORE, "wb")) {
         fwrite(&(RETVAL->nodeid), sizeof(uuid_node_t), 1, fd);
         fclose(fd);
      };
   }
   get_current_time(&timestamp);
   RETVAL->next_save = timestamp;
   errno = 0; 
OUTPUT:
   RETVAL

void
create(self)
   uuid_context_t *self;
ALIAS:
   Data::UUID::create_bin = F_BIN
   Data::UUID::create_str = F_STR
   Data::UUID::create_hex = F_HEX
   Data::UUID::create_b64 = F_B64
PREINIT:
   uuid_time_t  timestamp;
   unsigned16   clockseq;
   uuid_t       uuid;
   FILE        *fd;
PPCODE:
   LOCK;
   clockseq = self->state.cs;
   get_current_time(&timestamp);
   if ( self->state.ts == I64(0) ||
      memcmp(&(self->nodeid), &(self->state.node), sizeof(uuid_node_t)))
      clockseq = true_random();
   else if (timestamp < self->state.ts)
      clockseq++;

   format_uuid_v1(&uuid, clockseq, timestamp, self->nodeid);
   self->state.node = self->nodeid;
   self->state.ts   = timestamp;
   self->state.cs   = clockseq;
   if (timestamp > self->next_save ) {
      if(fd = fopen(UUID_STATE_NV_STORE, "wb")) {
         fwrite(&(self->state), sizeof(uuid_state_t), 1, fd);
         fclose(fd);
      }
      self->next_save = timestamp + (10 * 10 * 1000 * 1000);
   }
   UNLOCK;
   ST(0) = make_ret(uuid, ix);
   XSRETURN(1);

void
create_from_name(self,nsid,name)
   uuid_context_t *self;
   uuid_t         *nsid;
   char           *name;
ALIAS:
   Data::UUID::create_from_name_bin = F_BIN
   Data::UUID::create_from_name_str = F_STR
   Data::UUID::create_from_name_hex = F_HEX
   Data::UUID::create_from_name_b64 = F_B64
PREINIT:
   MD5_CTX       c;
   unsigned char hash[16];
   uuid_t        net_nsid; 
   uuid_t        uuid;
PPCODE:
   net_nsid = *nsid;
   net_nsid.time_low            = htonl(net_nsid.time_low);
   net_nsid.time_mid            = htons(net_nsid.time_mid);
   net_nsid.time_hi_and_version = htons(net_nsid.time_hi_and_version);

   MD5Init(&c);
   MD5Update(&c, (unsigned char*)&net_nsid, sizeof(uuid_t));
   MD5Update(&c, (unsigned char*)name, strlen(name));
   MD5Final(hash, &c);

   format_uuid_v3(&uuid, hash);
   ST(0) = make_ret(uuid, ix);
   XSRETURN(1);

int 
compare(self,u1,u2)
   uuid_context_t *self;
   uuid_t         *u1; 
   uuid_t         *u2;
PREINIT:
   int i;
CODE:
   RETVAL = 0;
   CHECK(u1->time_low, u2->time_low);
   CHECK(u1->time_mid, u2->time_mid);
   CHECK(u1->time_hi_and_version, u2->time_hi_and_version);
   CHECK(u1->clock_seq_hi_and_reserved, u2->clock_seq_hi_and_reserved);
   CHECK(u1->clock_seq_low, u2->clock_seq_low);
   for (i = 0; i < 6; i++) {
      if (u1->node[i] < u2->node[i])
         RETVAL = -1;
      if (u1->node[i] > u2->node[i])
         RETVAL =  1;
   }
OUTPUT:
   RETVAL

void
to_string(self,uuid)
   uuid_context_t *self;
   uuid_t         *uuid;
ALIAS:
   Data::UUID::to_hexstring = F_HEX
   Data::UUID::to_b64string = F_B64
PREINIT:
   STRLEN len;
   char   buf[BUFSIZ];
   int    i;
PPCODE:
   ST(0) = make_ret(*uuid, ix ? ix : F_STR);
   XSRETURN(1);

void
from_string(self,str) 
   uuid_context_t *self;
   char           *str;
ALIAS:
   Data::UUID::from_hexstring = F_HEX
   Data::UUID::from_b64string = F_B64
PREINIT:
   uuid_t         uuid;
   char          *from, *to;
   int            i, c;
   unsigned char  buf[4];
PPCODE:
   switch(ix) {
   case F_BIN:
   case F_STR:
   case F_HEX:
      from = str;
      memset(&uuid, 0x00, sizeof(uuid_t));
      if ( from[0] == '0' && from[1] == 'x' )
         from += 2;
      for (i = 0; i < sizeof(uuid_t); i++) {
         if (*from == '-')
	    from++; 
         if (sscanf(from, "%2x", &c) != 1) 
	    croak("from_string(%s) failed...\n", str);
         ((unsigned char*)&uuid)[i] = (unsigned char)c;
         from += 2;
      }
      uuid.time_low            = ntohl(uuid.time_low);
      uuid.time_mid            = ntohs(uuid.time_mid);
      uuid.time_hi_and_version = ntohs(uuid.time_hi_and_version);
      break;
   case F_B64:
      from = str; to = (char*)&uuid;
      while(from < (str + strlen(str))) {
	 i = 0; memset(buf, 255, 4);
	 do {
	    c = index64[*from++];
	    if (c != 255) buf[i++] = (unsigned char)c;
	    if (from == (str + strlen(str))) 
	       break;
         } while (i < 4);
	 if (buf[0] == 254 || buf[1] == 254)
	    break;
         *to++ = (buf[0] << 2) | ((buf[1] & 0x30) >> 4);
	 if (buf[2] == 254) break;

	 *to++ = ((buf[1] & 0x0F) << 4) | ((buf[2] & 0x3C) >> 2);
	 if (buf[3] == 254) break;

	 *to++ = ((buf[2] & 0x03) << 6) | buf[3];
      }
      break;
   default:
      croak("invalid type %d\n", ix);
      break;
   }
   ST(0) = make_ret(uuid, F_BIN);
   XSRETURN(1);

void
DESTROY(self)
   uuid_context_t *self;
PREINIT:
   FILE           *fd;
CODE:
   if (fd = fopen(UUID_NODEID_NV_STORE, "wb")) {
      fwrite(&(self->nodeid), sizeof(uuid_node_t), 1, fd);
      fclose(fd);
   };
   Safefree(self);
