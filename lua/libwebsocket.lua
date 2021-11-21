
local ffi = require("ffi")

ffi.cdef[[

void	REQUEST_get_header_value( const char *data, const char *requested_value_name, char *dst, const unsigned int dst_len );

void	WEBSOCKET_generate_handshake( const char *data, char *dst, const unsigned int dst_len );
int		WEBSOCKET_set_content( const char *data, int64_t data_length, unsigned char *dst, const unsigned int dst_len );
int		WEBSOCKET_get_content( const char *data, int64_t data_length, unsigned char *dst, const unsigned int dst_len, unsigned char *hdr );
short	WEBSOCKET_valid_connection( const char *data );
int		WEBSOCKET_client_version( const char *data );
]]

local websocket = ffi.load("websocket")

return websocket