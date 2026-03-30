function Joint=hello1(flag,period_time,step_time)
switch flag
      case 01  
% 六足 伸腿  18个关节   
% 'Rleg1_joint1';   'Rleg1_joint2';   'Rleg1_joint3'; [-30,90],[-0.4,48.5],[-25.6,55.5]
% 'Rleg2_joint1';   'Rleg2_joint2';   'Rleg2_joint3';   
% 'Rleg3_joint1';   'Rleg3_joint2';   'Rleg3_joint3'; 
% 'Lleg1_joint1';   'Lleg1_joint2';   'Lleg1_joint3'; [-90,30],[-0.4,48.5],[-25.6,55.5]
% 'Lleg2_joint1';  'Lleg2_joint2';   'Lleg2_joint3';  
% 'Lleg3_joint1';   'Lleg3_joint2';   'Lleg3_joint3';  0     18    20        0     18    20        0     18    20       0     18    20        0     18    20       0     18    20 ;

          q_mark_1=[ 90     48    55       90     48    55       90     48    55     -90     48    55      -90     48    55     -90     48    55 ;
                     45     48    30       45     48    30       45     48    30     -45     48    30      -45     48    30     -45     48    30 ; 
                      0     40   -25.6        0     40   -25.6        0     40   -25.6       0     40   -25.6        0     40   -25.6       0     40   -25.6 ;
                      0      0     0        0      0     0        0      0     0       0      0     0        0      0     0       0      0     0;
                      0      0     0        0      0     0        0      0     0       0      0     0        0      0     0       0      0     0;
                      0      0     0        0      0     0        0      0     0       0      0     0        0      0     0       0      0     0
            ];
      
          Joint_1=bothsides_differ_spline(q_mark_1,period_time,step_time)/180*pi;
          Joint=[Joint_1];


     case 00001  
%            弯曲站
          q_mark_1=[ 0     0    32    -62   30   0       0    0    32    -62   30   0     0  0   0   0   0   0    0     0    0   0   0;
                   0     0    32    -62   30   0       0    0    32    -62   30   0     0  0   0   0   0   0    0     0    0   0   0;
            ];
      
          Joint_1=bothsides_differ_spline(q_mark_1,period_time,step_time)/180*pi;
          Joint=[Joint_1];
          case 00000001  
%            站立
        % eulerAngles=[-90;90;-180]/rad2deg;
        % passive front fall and stand up
%          q_mark=[
%             0 -20 50  -80  10  5   0 20 10  -20  10  8    0 0 0  0     -90  70 30    0 60 92  90;
% 0     0    0    -130   60   0        0    0    0  -130  60   0     0  -10   0    -110     0    100   -70   0   130; 
%             0 0 0 -10 0 0        0 0 0 -10 0 0         0 -10 0      -70 0 130 -70 0 130;];
        q_mark_1=[ 0     0    10    -20   10   0       0    0    10  -20  10   0     0  0   0   0   0   0    0     0    0   0   0;
                   0     0    10    -20   10   0       0    0    10  -20  10   0     0  0   0   0   0   0    0     0    0   0   0;
             %  -13  0       0      -70      60   0    17   0     0      -130      60  0   0 -10 0    -10   0   -70 130    10  0    -70 130;%%%%%%%%目标动作
            ];
      
          Joint_1=bothsides_differ_spline(q_mark_1,period_time,step_time)/180*pi;
%         Joint_2=bothsides_differ_spline(q_mark_2,period_time,step_time)/180*pi;
        Joint=[Joint_1];   

         
        case 000000000000015   
%            任意腿交叉到标准
        % eulerAngles=[-90;90;-180]/rad2deg;
        % passive front fall and stand up
%          q_mark=[
%             0 -20 50  -80  10  5   0 20 10  -20  10  8    0 0 0  0     -90  70 30    0 60 92  90;
% 0     0    0    -130   60   0        0    0    0  -130  60   0     0  -10   0    -110     0    100   -70   0   130; 
%             0 0 0 -10 0 0        0 0 0 -10 0 0         0 -10 0      -70 0 130 -70 0 130;];
        q_mark_1=[-11     0  -15     -30   40   0      11    0  -45   -30  40   0     0  -10   0   -10  10   -70    130     10    0   -70   130; 
                    0     0  -11     -40   50   0       0    0  -35   -60  50   0     0  -10   0   -10   0   -70    130     10    0   -70   130;
                    0     0    0    -130   60   0       0    0    0  -130  60   0     0  -10   0   -10   0   -70    130     10    0   -70   130;
             %  -13  0       0      -70      60   0    17   0     0      -130      60  0   0 -10 0    -10   0   -70 130    10  0    -70 130;%%%%%%%%目标动作
            ];
      
          Joint_1=bothsides_differ_spline(q_mark_1,period_time,step_time)/180*pi;
%         Joint_2=bothsides_differ_spline(q_mark_2,period_time,step_time)/180*pi;
        Joint=[Joint_1];   

end