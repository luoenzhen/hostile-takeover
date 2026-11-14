#include "../game/iphone/hdscale.h"
#include <cassert>
#include <vector>
int main() {
    uint32_t one=0xff123456, out[4]={};
    WIUpscale2x(&one,out,1,1);
    for (int i=0;i<4;++i) assert(out[i]==one);
    const uint32_t diagonal[9]={0,1,0,1,0,0,0,0,0};
    uint32_t scaled[36]={};
    WIUpscale2x(diagonal,scaled,3,3);
    assert(scaled[14]==1); // join a diagonal without blurring the flat region
    assert(scaled[15]==0 && scaled[20]==0 && scaled[21]==0);
    for (int w=1;w<39;++w) for (int h=1;h<27;++h) {
        std::vector<uint32_t> in(w*h,42), result(w*h*4+2,123);
        WIUpscale2x(in.data(),result.data()+1,w,h);
        assert(result.front()==123 && result.back()==123);
        for (int i=1;i<=w*h*4;++i) assert(result[i]==42);
    }
}
