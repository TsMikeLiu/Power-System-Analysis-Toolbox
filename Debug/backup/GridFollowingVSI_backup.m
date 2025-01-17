% This class defines the model of grid-following VSI

% Author(s): Yitong Li, Yunjie Gu

%% Notes
%
% The model is in 
% ac-side: load convention, admittance form.
% dc-side: source convention, impedance form.

%% Class

classdef GridFollowingVSI < SimplusGT.Class.ModelAdvance
    
    % For temporary use
    properties(Access = protected)
        i_q_r;
    end
    
    methods
        % constructor
        function obj = GridFollowingVSI(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods(Static)
        
        function [State,Input,Output] = SignalList(obj)
          	% Notes:
            % P_dc is the output power to dc side.
            % The "_i" in "i_d_i", "i_q_i", "v_dc_i" means integral. These
            % states appear because PI controllers are used
            % correspondingly.
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                State = {'i_d','i_q','i_d_i','i_q_i','w_pll_i','w','theta','v_dc','v_dc_i'};
            elseif obj.ApparatusType == 11
                State = {'i_d','i_q','i_d_i','i_q_i','w_pll_i','w','theta'};
            else
                error('Error: Invalid ApparatusType.');
            end
        	Input = {'v_d','v_q','ang_r','P_dc'};
            Output = {'i_d','i_q','w','v_dc','theta'};
        end
        
        function [x_e,u_e,xi] = Equilibrium(obj)
            % Get the power PowerFlow values
            P 	= obj.PowerFlow(1);
            Q	= obj.PowerFlow(2);
            V	= obj.PowerFlow(3);
            xi	= obj.PowerFlow(4);
            w   = obj.PowerFlow(5);

            % Get parameters
            C_dc    = obj.Para(1);
            V_dc    = obj.Para(2);
            L       = obj.Para(11);
            R       = obj.Para(12);
            W0      = obj.Para(13);
            Gi_cd   = obj.Para(14);

            % Calculate paramters
            i_d = P/V;
            i_q = -Q/V;     % Because of conjugate "i"
            v_d = V;
            v_q = 0;
            i_dq = i_d + 1j*i_q;
            v_dq = v_d + 1j*v_q;
            e_dq = v_dq - i_dq * (R + 1j*L*w);
            e_d = real(e_dq);
            e_q = imag(e_dq);
            i_d_i = e_d + Gi_cd*W0*L*(-i_q);
            i_q_i = e_q - Gi_cd*W0*L*(-i_d);
            i_d_r = i_d;
            i_q_r = i_q;
            w_pll_i = w;
            v_dc_i = i_d;
            v_dc = V_dc;
            P_dc = e_d*i_d + e_q*i_q;
            ang_r = 0;
            theta = xi;
            
            % ??? Temp
            obj.i_q_r = i_q_r;

            % Get equilibrium
            x_e_1 = [i_d; i_q; i_d_i; i_q_i; w_pll_i; w; theta];
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                x_e = [x_e_1; v_dc; v_dc_i];
            elseif obj.ApparatusType == 11
                x_e = x_e_1;
            else
                error('Error: Invalid ApparatusType.');
            end
        	u_e = [v_d; v_q; ang_r; P_dc];
        end

        function [Output] = StateSpaceEqu(obj,x,u,CallFlag)
            % Get the power PowerFlow values
            P 	= obj.PowerFlow(1);
            Q	= obj.PowerFlow(2);
            V	= obj.PowerFlow(3);
            xi	= obj.PowerFlow(4);
            w   = obj.PowerFlow(5);
            
           	% Get parameters
            C_dc    = obj.Para(1);
            v_dc_r  = obj.Para(2);
            kp_v_dc = obj.Para(3);      % v_dc, P
            ki_v_dc = obj.Para(4);      % v_dc, I
            kp_pll  = obj.Para(5);      % PLL, P
            ki_pll  = obj.Para(6);      % PLL, I
            tau_pll = obj.Para(7);
            kp_i_dq = obj.Para(8);      % i_dq, P
            ki_i_dq = obj.Para(9);      % i_dq, I
            k_pf    = obj.Para(10);
            L       = obj.Para(11);     % L filter
            R       = obj.Para(12);     % L filter's inner resistance
            W0      = obj.Para(13);
            Gi_cd   = obj.Para(14);     % Current cross-decouping gain
            
            % Get states
          	i_d   	= x(1);
         	i_q   	= x(2);
          	i_d_i  	= x(3);
            i_q_i 	= x(4);
            w_pll_i = x(5);
            w       = x(6);
            theta   = x(7);
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                v_dc  	= x(8);
                v_dc_i 	= x(9);
            elseif obj.ApparatusType == 11
                v_dc    = v_dc_r;
                v_dc_i  = 0;
            else
                error('Error: Invalid ApparatusType.');
            end

            % Get input
        	v_d    = u(1);
            v_q    = u(2);
            ang_r  = u(3);
            P_dc   = u(4);
            
            % State space equations
            % dx/dt = f(x,u)
            % y     = g(x,u)
            if CallFlag == 1    
            % ### Call state equation: dx/dt = f(x,u)
                
              	% Current limit
                i_d_limit = 1.5;
                i_q_limit = 1.5;
                
                % Get current reference
               	if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                    % Anti wind-up for vdc control
                    v_dc_i = min(v_dc_i,i_d_limit);
                    v_dc_i = max(v_dc_i,-i_d_limit);
                    
                    % DC-link control
                    i_d_r = (v_dc_r - v_dc)*kp_v_dc + v_dc_i;
                elseif obj.ApparatusType == 11
                    % % Active power control                                           
                    i_d_r = P/V;
                else
                   error('Invalid ApparatusType.');
                end
                
              	% i_q_r = i_d_r * -k_pf;  % Constant pf control, PQ node in power flow
                i_q_r = obj.i_q_r;    % Constant iq control, PQ/PV node in power flow
                
                EnableSaturation = 0;
                
                % Current saturation
                if EnableSaturation
                i_d_r = min(i_d_r,i_d_limit);
                i_d_r = max(i_d_r,-i_d_limit);
                i_q_r = min(i_q_r,i_q_limit);
                i_q_r = max(i_q_r,-i_q_limit);
                end
                
                % Ac voltage limit
             	e_d_limit_H = 1.5;
                e_d_limit_L = -1.5;
               	e_q_limit_H = 1.5;
                e_q_limit_L = -1.5;
                
                % Current controller anti-windup
                if EnableSaturation
             	i_d_i = min(i_d_i,e_d_limit_H);
                i_d_i = max(i_d_i,e_d_limit_L);
             	i_q_i = min(i_q_i,e_q_limit_H);
                i_q_i = max(i_q_i,e_q_limit_L);
                end
                
                % Ac voltage (duty cycle*v_dc)
                e_d = -(i_d_r - i_d)*kp_i_dq + i_d_i - Gi_cd*W0*L*(-i_q);
                e_q = -(i_q_r - i_q)*kp_i_dq + i_q_i + Gi_cd*W0*L*(-i_d);
                
                % Ac voltage (duty cycle) saturation
                if EnableSaturation
                e_d = min(e_d,e_d_limit_H);
                e_d = max(e_d,e_d_limit_L);
                e_q = min(e_q,e_q_limit_H);
                e_q = max(e_q,e_q_limit_L);
                end
                
                % PLL angle measurement
                switch 2                                                                   % ???
                    case 1
                        e_ang = atan2(v_q,v_d) - ang_r;     % theta-PLL
                    case 2
                        e_ang = v_q - ang_r;                % vq-PLL
                    case 3
                        Q = v_q*i_d - v_d*i_q;              % Q-PLL
                        % Q = e_q*i_d - e_d*i_q;     
                        if i_d<=0
                            e_ang = - Q - ang_r;
                        else
                            e_ang = Q - ang_r;
                        end
                    otherwise
                        error(['Error']);
                end
                % Notes:
                % "- ang_r" gives the reference in load convention, like
                % the Tw port.
                %
                % Noting that Q is proportional to v_q*i_d, this means the
                % direction of active power influences the sign of Q or
                % equivalently the PI controller in the PLL. In order to
                % make sure case 3 is equivalent to case 1 or 2, the
                % controller for case 3 is dependent the power flow
                % direction.
                
                % Frequency limit
                w_limit_H = W0*1.5;
                w_limit_L = W0*0.5;
                
                % Frequency saturation
                w = min(w,w_limit_H);
                w = max(w,w_limit_L);
                        
                % State equations
                if obj.ApparatusType == 10
                    dv_dc = (e_d*i_d + e_q*i_q - P_dc)/v_dc/C_dc; 	% C_dc
                    dv_dc_i = (v_dc_r - v_dc)*ki_v_dc;             	% v_dc I
                elseif obj.ApparatusType == 12
                    i_dc = P_dc/v_dc_r;
                  	dv_dc = ((e_d*i_d + e_q*i_q)/v_dc - i_dc)/C_dc; 	% C_dc
                    dv_dc_i = (v_dc_r - v_dc)*ki_v_dc;                  % v_dc I
                elseif obj.ApparatusType == 11
                    % No dc link control
                else
                    error('Invalid ApparatusType.');
                end
                di_d_i = -(i_d_r - i_d)*ki_i_dq;               	% i_d I
                di_q_i = -(i_q_r - i_q)*ki_i_dq;             	% i_q I
                di_d = (v_d - R*i_d + w*L*i_q - e_d)/L;      	% L
                di_q = (v_q - R*i_q - w*L*i_d - e_q)/L;      	% L
                dw_pll_i = e_ang*ki_pll;                       	% PLL I
             	dw = (w_pll_i + e_ang*kp_pll - w)/tau_pll;      % PLL tau
                dtheta = w;
                
                % Output state
                f_xu_1 = [di_d; di_q; di_d_i; di_q_i; dw_pll_i; dw; dtheta];
                if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                    f_xu = [f_xu_1; dv_dc; dv_dc_i];
                elseif obj.ApparatusType == 11
                    f_xu = f_xu_1;
                else
                    error('Invalid ApparatusType.');
                end
                Output = f_xu;
                
            elseif CallFlag == 2
          	% ### Call output equation: y = g(x,u)
                g_xu = [i_d; i_q; w; v_dc; theta];
                Output = g_xu;
            end
        end

    end

end     % End class definition