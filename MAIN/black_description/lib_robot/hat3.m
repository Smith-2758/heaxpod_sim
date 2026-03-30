function c_hat=hat3(c)
c1=c(1);
c2=c(2);
c3=c(3);
c_hat=[0 -c3 c2;
       c3 0 -c1;
       -c2 c1 0;];