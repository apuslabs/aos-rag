#ifndef SQLITE_LEMBED_H
#define SQLITE_LEMBED_H

#include "sqlite3ext.h"
#include "llama.h"

#define SQLITE_LEMBED_VERSION "v0.0.1-alpha.8"
#define SQLITE_LEMBED_DATE "2024-10-18"
#define SQLITE_LEMBED_SOURCE "a42037e6992c5a586e8ea387bc278ff09697a175"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
__declspec(dllexport)
#endif
int sqlite3_lembed_init(sqlite3 *db, char **pzErrMsg, const sqlite3_api_routines *pApi);

#ifdef __cplusplus
}  /* end of the 'extern "C"' block */
#endif

#endif /* ifndef SQLITE_LEMBED_H */