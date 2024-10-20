#ifndef FLOODING_TABLE_H
#define FLOODING_TABLE_H

typedef struct {
    uint16_t lastSeq;
    uint16_t lastDest;
} FloodingTable;

#endif