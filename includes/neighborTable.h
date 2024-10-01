#ifndef NEIGHBOR_TABLE_H
#define NEIGHBOR_TABLE_H

typedef struct {
    uint16_t neighborAddress;
    uint8_t linkQuality;
    bool isActive;
} NeighborTable;

#endif