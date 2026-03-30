function robot=robot3D_description()
load('under_joint_position.mat');
load('com.mat')
load('Inertia.mat');
load('mass.mat')

com7=(mass(7)*com(:,7)+mass(8)*com(:,8))/(mass(7)+mass(8));
com14=(mass(14)*com(:,14)+mass(15)*com(:,15))/(mass(14)+mass(15));

Inertia(:,:,7)=Inertia(:,:,7)+mass(7)*hat3(com(:,7)-com7)*(hat3(com(:,7)-com7))'...
	+Inertia(:,:,8)+mass(8)*hat3(com(:,8)-com7)*(hat3(com(:,8)-com7))';
Inertia(:,:,14)=Inertia(:,:,14)+mass(14)*hat3(com(:,14)-com14)*(hat3(com(:,14)-com14))'...
	+Inertia(:,:,15)+mass(15)*hat3(com(:,15)-com14)*(hat3(com(:,15)-com14))';

Inertia(:,:,8)=[];
Inertia(:,:,15)=[];

com(:,7)=com7;
com(:,14)=com14;
com(:,8)=[];
com(:,15)=[];

mass(7)=mass(7)+mass(8);
mass(14)=mass(14)+mass(15);
mass([8,15])=[];

p=under_joint_position;
% p=p.*(abs(p)>8e-4);
% p=[-1 0 0;0 -1 0; 0 0 1]*p;
name      =  { 'body';   'Rleg1_joint1';   'Rleg1_joint2';   'Rleg1_joint3';   'Rleg2_joint1';   'Rleg2_joint2';   'Rleg2_joint3';   'Rleg3_joint1';   'Rleg3_joint2';   'Rleg3_joint3';   'Lleg1_joint1';   'Lleg1_joint2';   'Lleg1_joint3';   'Lleg2_joint1';   'Lleg2_joint2';   'Lleg2_joint3';   'Lleg3_joint1';   'Lleg3_joint2';   'Lleg3_joint3'; };
id_me     =  [  1               2                 3                 4                 5                 6                 7					8                 9                10                11                12                13                14                15                16                17                18                19       ];
id_child  =  [  2               3                 4                 0                 6                 7                 0					9                 10               0                 12                13                0                 15                16                0                 18                19                0        ];
id_mother =  [  0               1                 2                 3                 1                 5                 6				    1                 8                9                 1                 11                12                1                 14                15                1                 17                18        ];
id_sister =  [  0               5                 0                 0                 8                 0                 0					11                0                0                 14                0                 0                 17                0                 0                 0                 0                 0        ];
joint_a   =  [  0               0                 -1               -1                 0                 -1               -1                 0                 -1              -1                 0                 1                 1                 0                 1                 1                 0                 1                 1
				0               0                 0                 0                 0                 0                 0                 0                 0                0                 0                 0                 0                 0                 0                 0                 0                 0                 0 
				0               1                 0                 0                 1                 0                 0                 1                 0                0                 1                 0                 0                 1                 0                 0                 1                 0                 0        ];
% joint_b   =  [  0               p(1,1)            p(1,2)            p(1,3)            p(1,4)            p(1,5)            p(1,6)	    	 p(1,7)           p(1,8)           p(1,9)            p(1,10)           p(1,11)           p(1,12)           p(1,13)           p(1,14)           p(1,15)           p(1,16)           p(1,17)           p(1,18)
% 				0               p(2,1)            p(2,2)            p(2,3)            p(2,4)            p(2,5)            p(2,6)			 p(2,7)           p(2,8)           p(2,9)            p(2,10)           p(2,11)           p(2,12)           p(2,13)           p(2,14)           p(2,15)           p(2,16)           p(2,17)           p(2,18)
% 				0               p(3,1)            p(3,2)            p(3,3)            p(3,4)            p(3,5)            p(3,6)			 p(3,7)           p(3,8)           p(3,9)            p(3,10)           p(3,11)           p(3,12)           p(3,13)           p(3,14)           p(3,15)           p(3,16)           p(3,17)           p(3,18)  ];
lb        =  [  0               -80               -90               -120              -80               -90               -120               -80              -90              -120              -80               -90               -120              -80               -90               -120              -80               -90               -120     ]/180*pi;
ub        =  [  0               80                90                0                 80                90                0                  80               90               0                 80                90                0                 80                90                0                 80                90                0        ]/180*pi;
			
			
for ii=1:length(id_me)
	%编号
	robot(ii).name   = name(ii);
	robot(ii).id     = id_me(ii);
	robot(ii).child  = id_child(ii);
	robot(ii).mother = id_mother(ii);
	robot(ii).sister = id_sister(ii);

	%几何参数
	robot(ii).a      = joint_a(:,ii);
% 	robot(ii).b      = joint_b(:,ii);
    robot(ii).b      = p(:,ii);
	robot(ii).lb     = lb(ii);
	robot(ii).ub     = ub(ii);

	%动态参数
	robot(ii).q = 0;
	robot(ii).p = [0 0 0]';
	robot(ii).R = eye(3);
	
	%碰撞参数
	robot(ii).collision=[];
end
robot=fkinematic(robot,1);
for ii=1:length(id_me)
	%惯量参数
	robot(ii).m  = mass(ii);
	robot(ii).I  = Inertia(:,:,ii);
	robot(ii).c  = com(:,ii)-robot(ii).p-[0;0.05;0.80638];
end

%碰撞点
%%右腿1
robot(4).collision(1).name = 'Rlegfoot1';
robot(4).collision(1).b    = [0;0;-1.305];
robot(4).collision(1).p    = [-90;0;0];
%%右腿2
robot(7).collision(1).name = 'Rlegfoot2';
robot(7).collision(1).b    = [0;0;-1.305];
robot(7).collision(1).p    = [-90;0;0];
%%右腿3
robot(10).collision(1).name = 'Rlegfoot3';
robot(10).collision(1).b    = [0;0;-1.305];
robot(10).collision(1).p    = [-90;0;0];
%%左腿1
robot(13).collision(1).name = 'Llegfoot1';
robot(13).collision(1).b    = [0;0;-1.305];
robot(13).collision(1).p    = [-90;0;0];
%%左腿2
robot(16).collision(1).name = 'Llegfoot2';
robot(16).collision(1).b    = [0;0;-1.305];
robot(16).collision(1).p    = [-90;0;0];
%%左腿3
robot(19).collision(1).name = 'Llegfoot3';
robot(19).collision(1).b    = [0;0;-1.305];
robot(19).collision(1).p    = [-90;0;0];