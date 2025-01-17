% This function re-arranges the netlist data of apparatuses.

% Author(s): Yitong Li, Yunjie Gu

%% Notes
%
% The apparatus model is in load convention.

function [ApparatusBusCell,ApparatusTypeCell,ParaCell,N_Apparatus] = RearrangeListApparatus(UserData,W0,ListBus)

%% Load data
[ListApparatus,ListApparatusChar]	 = xlsread(UserData,'Apparatus');

%% Rearrange data
[N_Apparatus,ColumnMax_Apparatus] = size(ListApparatus);
ListApparatusBus = ListApparatus(:,1);
ListApparatusType = ListApparatus(:,2);
ListApparatusBusChar = ListApparatusChar(:,1);

for k1 = 1:length(ListApparatusBusChar)
    if strcmpi(ListApparatusBusChar{k1},'Bus No.')
        break;
    end
end
ListApparatusBusChar = ListApparatusBusChar(k1+1:end);

% Get the apparatus bus in cell form
for n = 1:N_Apparatus
    if ~isnan(ListApparatusBus(n))
        ApparatusBusCell{n} = ListApparatusBus(n);
    else
        ApparatusBusCell{n} = str2num(ListApparatusBusChar{n});
        [~,~,AreaType]= SimplusGT.Toolbox.CheckBus(ApparatusBusCell{n}(1),ListBus);
        if AreaType == 2 % If the first bus is dc bus, then swap
            [ApparatusBusCell{n}(1),ApparatusBusCell{n}(2)] = deal(ApparatusBusCell{n}(2),ApparatusBusCell{n}(1));
        end
    end
end

% Get the apparatus type in cell form
for n = 1:N_Apparatus
    ApparatusTypeCell{n} = ListApparatus(n,2);
end

% Re-order the apparatus sequence
% ListApparatus = sortrows(ListApparatus,1);
% No re-order for now.

% Error check
if (ColumnMax_Apparatus>12)
    error(['Error: Apparatus data overflow.']); 
end

[~,ModeBus] = SimplusGT.CellMode(ApparatusBusCell);
if ModeBus~=1
    error(['Error: For each bus, one and only one apparatus has to be connected.']);
end

%% Default AC apparatus data
% ======================================
% Synchronous generator
% ======================================
Para0000.J  = 3.5;
Para0000.D  = 1;
Para0000.wL = 0.1;
Para0000.R  = 0.01;
Para0000.w0 = W0;

% ======================================
% Grid-following VSI (PLL-controlled)
% ======================================
% Dc link
Para0010.V_dc   = 2.5;
Para0010.C_dc   = 1.25; %2*0.1*Para0010.V_dc^2;
Para0010.f_v_dc = 20;           % (Hz) bandwidth, vdc

% Ac filter
Para0010.wLf = 0.03;
Para0010.R   = 0.01;

% PLL
Para0010.f_pll      = 20;       % (Hz) bandwidth, PLL
Para0010.f_tau_pll  = 200;      % (Hz) bandwidth, PLL low pass filter

% Current loop
Para0010.f_i_dq = 500;      	% (Hz) bandwidth, idq
Para0010.w0 = W0;   

% ======================================
% Grid-forming VSI (Droop-Controlled)
% ======================================
Para0020.wLf    =0.05;
Para0020.Rf     =0.05/5;
Para0020.wCf    =0.02;
Para0020.wLc    =0.01;
Para0020.Rc     =0.01/5;
Para0020.Xov    =0;
Para0020.Dw     =0.05;
Para0020.fdroop =20;    % (Hz) droop control bandwidth
Para0020.fvdq   =250;   % (Hz) vdc bandwidth
Para0020.fidq   =500;   % current control bandwidth
Para0020.w0     = W0;

% ======================================
% Ac infinite bus (short-circuit in small-signal)
% ======================================
Para0090 = [];

% ======================================
% Ac floating bus (open-circuit)
% ======================================
Para0100 = [];

%% Default DC apparatus data
% ======================================
% Grid-feeding buck
% ======================================
Para1010.Vdc  = 2;
Para1010.Cdc  = 0.8;
Para1010.wL   = 0.05;
Para1010.R    = 0.05/5;
Para1010.fi   = 500;
Para1010.fvdc = 10;
Para1010.w0   = W0;

% ======================================
% Dc infinite bus (short-circuit in small-signal)
% ======================================
Para1090 = [];

% ======================================
% Dc floating bus (open-circuit)
% ======================================
Para1100 = [];

%% Default hybrid apparatus data
% ======================================
% Interlink ac-dc converter
% ======================================
Para2000.C_dc   = 1.6;
Para2000.wL_ac  = 0.05;
Para2000.R_ac   = 0.01;
Para2000.wL_dc  = 0.02;
Para2000.R_dc   = 0.02/5;
Para2000.fidq   = 500;
Para2000.fvdc   = 10;
Para2000.fpll   = 10;
Para2000.w0     = W0;   

%% Re-arrange apparatus data
% Get the size of netlist
[N_Apparatus,ColumnMax_Apparatus] = size(ListApparatus);

% Find the index of user-defined data
netlist_apparatus_NaN = isnan(ListApparatus(:,3:ColumnMax_Apparatus));
[row,column] = find(netlist_apparatus_NaN == 0);     
column = column+2;

% Initialize the apparatus parameters by default parameters
for i = 1:N_Apparatus
    ApparatusBus   = ApparatusBusCell{i};
    ApparatusType  = ListApparatusType(i);
    switch floor(ApparatusType/10)
        % ### AC apparatuses
        case 0     
            ParaCell{i} = Para0000;     % Synchronous machine
        case 1
            ParaCell{i} = Para0010;     % Grid-following inverter
      	case 2
            ParaCell{i} = Para0020;     % Grid-forming inverter
        case 3
            % Yue's Full-Order Machine
        case 9
            ParaCell{i} = Para0090;     % Ac inifnite bus
        case 10
            ParaCell{i} = Para0100;     % Ac floating bus, i.e., no apparatus
        
        % ### DC apparatuses
        case 101
            ParaCell{i} = Para1010;     % Grid-following buck
        case 109
            ParaCell{i} = Para1090;     % Dc infinite bus
        case 110
            ParaCell{i} = Para1100;     % Ac floating bus, i.e., no apparatus
            
        % ### Hybrid ac-dc apparatuses
        case 200
            ParaCell{i} = Para2000;     % Interlinking ac-dc converter
            
        % ### Error check
        otherwise
            error(['Error: apparatus type, bus ' num2str(ApparatusBus) ' type ' num2str(ApparatusType) '.']);
    end
end

% Replace the default data by customized data
% Notes: 
% This method can reduce the calculation time of "for" loop.
% The "for" loop runs only when "row" is not empty.
%
% The sequence of cases are determined by the excel form. This also
% decouples the sequence between the excel form and the system object.
for i = 1:length(row)
  	ApparatusBus   = ApparatusBusCell{row(i)};
	ApparatusType	= ListApparatusType(row(i));
 	UserValue 	= ListApparatus(row(i),column(i));     % Customized value
    SwitchFlag = column(i)-2;                   	% Find the updated parameter
  	if floor(ApparatusType/10) == 0                    % Synchronous machine
        switch SwitchFlag 
         	case 1; ParaCell{row(i)}.J  = UserValue;
            case 2; ParaCell{row(i)}.D  = UserValue;
            case 3; ParaCell{row(i)}.wL = UserValue;
            case 4; ParaCell{row(i)}.R  = UserValue; 
            otherwise
                error(['Error: paramter overflow, bus ' num2str(ApparatusBus) 'type ' num2str(ApparatusType) '.']);
        end
    elseif (floor(ApparatusType/10) == 1)              % Grid-following inverter
        switch SwitchFlag
            case 1; ParaCell{row(i)}.V_dc   = UserValue;
            case 2; ParaCell{row(i)}.C_dc   = UserValue;
            case 3; ParaCell{row(i)}.wL     = UserValue;
            case 4; ParaCell{row(i)}.R      = UserValue;
            case 5; ParaCell{row(i)}.f_v_dc = UserValue;
            case 6; ParaCell{row(i)}.f_pll  = UserValue;
            case 7; ParaCell{row(i)}.f_i_dq = UserValue;
            otherwise
                error(['Error: parameter overflow, bus ' num2str(ApparatusBus) 'type ' num2str(ApparatusType) '.']);
        end
    elseif floor(ApparatusType/10) == 2                % Grid-forming inverter
        switch SwitchFlag
            case 1;  ParaCell{row(i)}.wLf     = UserValue;
          	case 2;  ParaCell{row(i)}.Rf      = UserValue;
          	case 3;  ParaCell{row(i)}.wCf     = UserValue;
           	case 4;  ParaCell{row(i)}.wLc  	  = UserValue;
         	case 5;  ParaCell{row(i)}.Rc  	  = UserValue;
           	case 6;  ParaCell{row(i)}.Xov 	  = UserValue;
            case 7;  ParaCell{row(i)}.Dw      = UserValue;
            case 8;  ParaCell{row(i)}.fdroop  = UserValue;
          	case 9;  ParaCell{row(i)}.fvdq    = UserValue;
          	case 10; ParaCell{row(i)}.fidq    = UserValue; 
            otherwise
                error(['Error: parameter overflow, bus ' num2str(ApparatusBus) 'type ' num2str(ApparatusType) '.']);
        end
    elseif floor(ApparatusType/10) == 101 % Grid-feeding buck
        switch SwitchFlag
            case 1;  ParaCell{row(i)}.Vdc   = UserValue;
          	case 2;  ParaCell{row(i)}.Cdc   = UserValue;
          	case 3;  ParaCell{row(i)}.wL    = UserValue;
           	case 4;  ParaCell{row(i)}.R  	= UserValue;
         	case 5;  ParaCell{row(i)}.fi  	= UserValue;
           	case 6;  ParaCell{row(i)}.fvdc 	= UserValue;
            otherwise
                error(['Error: parameter overflow, bus ' num2str(ApparatusBus) 'type ' num2str(ApparatusType) '.']);
        end
    elseif floor(ApparatusType/10) == 200 % Interlink ac-dc converter
        switch SwitchFlag
            case 1;  ParaCell{row(i)}.C_dc  = UserValue;
            case 2;  ParaCell{row(i)}.wL_ac = UserValue;
            case 3;  ParaCell{row(i)}.R_ac  = UserValue;
            case 4;  ParaCell{row(i)}.wL_dc = UserValue;
            case 5;  ParaCell{row(i)}.R_dc  = UserValue;
            case 6;  ParaCell{row(i)}.fidq  = UserValue;
            case 7;  ParaCell{row(i)}.fvdc  = UserValue;
            case 8;  ParaCell{row(i)}.fpll  = UserValue;
            otherwise
                error(['Error: parameter overflow, bus ' num2str(ApparatusBus) 'type ' num2str(ApparatusType) '.']);
        end
    end
end

end