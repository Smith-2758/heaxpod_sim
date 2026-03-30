function ZMP=cal_ZMP(F,tao)
h=0.019;
ZMP=zeros(2,1);
ZMP(1)=(-F(1)*h-tao(2))/F(3);
ZMP(2)=(-F(2)*h+tao(1))/F(3);