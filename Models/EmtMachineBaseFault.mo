model EmtMachineBaseFault "Induction-machine electromagnetic transient base with one bolted terminal fault"
  parameter Modelica.Units.SI.Voltage VNominal=100 "Source RMS voltage, line to neutral";
  parameter Modelica.Units.SI.Frequency fNominal=50 "Source electrical frequency";
  parameter Modelica.Units.SI.Time tStart=0.1 "Direct-on-line contactor closing time";
  parameter Modelica.Units.SI.Torque TLoad=161.4 "Opposing load torque at wLoad";
  parameter Modelica.Units.SI.AngularVelocity wLoad(displayUnit="rev/min")=1440.45*2*Modelica.Constants.pi/60 "Speed at which quadratic load equals TLoad";
  parameter Modelica.Units.SI.Inertia JLoad=0.29 "External load inertia, additional to imcData.Jr";
  parameter Modelica.Units.SI.Resistance RLine=0.005 "Series line resistance per phase";
  parameter Modelica.Units.SI.Inductance LLine=0.03/(2*Modelica.Constants.pi*50) "Series line inductance per phase; default X=0.03 ohm at 50 Hz";
  final parameter Modelica.Units.SI.Reactance XLine=2*Modelica.Constants.pi*fNominal*LLine "Derived series line reactance per phase at fNominal";
  parameter Modelica.Units.SI.Time tFault=1.5 "Terminal fault closing time";
  parameter Modelica.Units.SI.Time tClear=0.1 "Fault duration; opens at tFault+tClear";
  parameter Modelica.Units.SI.Resistance RFault=1e-5 "Bolted fault switch on-resistance per phase";
  Modelica.Blocks.Sources.BooleanExpression faultCommand[3](each y=time>=tFault and time<tFault+tClear)
    annotation(Placement(transformation(extent={{70,55},{90,75}})));
  Modelica.Electrical.Polyphase.Ideal.IdealClosingSwitch faultSwitch(m=3,Ron=fill(RFault,3),Goff=fill(1e-5,3))
    annotation(Placement(transformation(extent={{110,10},{130,30}})));
  Modelica.Electrical.Polyphase.Basic.Star faultStar(m=3)
    annotation(Placement(transformation(extent={{130,10},{150,30}})));
  Modelica.Electrical.Analog.Basic.Ground faultGround
    annotation(Placement(transformation(extent={{150,-10},{170,10}})));
  parameter Modelica.Electrical.Machines.Utilities.ParameterRecords.IM_SquirrelCageData imcData "Editable MSL machine data; defaults give the documented nominal point"
    annotation(Placement(transformation(extent={{-115,-110},{-95,-90}})));
  Modelica.Electrical.Machines.BasicMachines.InductionMachines.IM_SquirrelCage aimc(
    p=imcData.p, fsNominal=imcData.fsNominal, Rs=imcData.Rs,
    TsRef=imcData.TsRef, alpha20s=imcData.alpha20s, Lszero=imcData.Lszero,
    Lssigma=imcData.Lssigma, Jr=imcData.Jr, Js=imcData.Js,
    frictionParameters=imcData.frictionParameters,
    statorCoreParameters=imcData.statorCoreParameters,
    strayLoadParameters=imcData.strayLoadParameters,
    Lm=imcData.Lm, Lrsigma=imcData.Lrsigma, Rr=imcData.Rr,
    TrRef=imcData.TrRef, alpha20r=imcData.alpha20r,
    TsOperational=293.15, TrOperational=293.15,
    phiMechanical(start=0,fixed=true), wMechanical(start=0,fixed=true,displayUnit="rev/min"))
    annotation(Placement(transformation(extent={{-50,-120},{-10,-80}})));
  Modelica.Electrical.Polyphase.Sources.SineVoltage sineVoltage(
    m=3, V=fill(sqrt(2)*VNominal,3), f=fill(fNominal,3),
    phase={0,-2*Modelica.Constants.pi/3,-4*Modelica.Constants.pi/3})
    annotation(Placement(transformation(origin={-20,90},extent={{-10,-10},{10,10}},rotation=90)));
  Modelica.Electrical.Polyphase.Basic.Star sourceStar(m=3)
    annotation(Placement(transformation(origin={-90,110},extent={{-10,-10},{10,10}},rotation=180)));
  Modelica.Electrical.Analog.Basic.Ground sourceGround
    annotation(Placement(transformation(origin={-130,110},extent={{-10,-10},{10,10}},rotation=270)));
  Modelica.Blocks.Sources.BooleanStep startCommand[3](each startTime=tStart)
    annotation(Placement(transformation(extent={{-110,45},{-90,65}})));
  Modelica.Electrical.Polyphase.Ideal.IdealClosingSwitch startSwitch(
    m=3, Ron=fill(1e-5,3), Goff=fill(1e-5,3))
    annotation(Placement(transformation(origin={-20,55},extent={{-10,10},{10,-10}},rotation=270)));
  Modelica.Electrical.Polyphase.Basic.Resistor lineR(m=3,R=fill(RLine,3))
    annotation(Placement(transformation(origin={-20,20},extent={{-10,-10},{10,10}},rotation=270)));
  Modelica.Electrical.Polyphase.Basic.Inductor lineL(m=3,L=fill(LLine,3))
    annotation(Placement(transformation(origin={-20,-15},extent={{-10,-10},{10,10}},rotation=270)));
  Modelica.Electrical.Machines.Sensors.CurrentQuasiRMSSensor currentRMS
    annotation(Placement(transformation(origin={-20,-48},extent={{-10,-10},{10,10}},rotation=270)));
  Modelica.Electrical.Machines.Utilities.TerminalBox terminalBox(terminalConnection="Y")
    annotation(Placement(transformation(extent={{-50,-88},{-10,-48}})));
  Modelica.Mechanics.Rotational.Components.Inertia loadInertia(J=JLoad)
    annotation(Placement(transformation(extent={{20,-115},{50,-85}})));
  Modelica.Mechanics.Rotational.Sources.QuadraticSpeedDependentTorque loadTorque(
    tau_nominal=-TLoad,w_nominal=wLoad,TorqueDirection=false,useSupport=false)
    annotation(Placement(transformation(extent={{110,-115},{80,-85}})));
  Modelica.Units.SI.Current iSource[3] "Source currents positive toward line";
  Modelica.Units.SI.Voltage vTerminal[3] "Machine terminal voltages relative to source neutral";
  Modelica.Units.SI.Voltage terminalVRMS "Instantaneous three-phase magnitude; phase RMS in balanced steady state";
initial equation
  aimc.is=zeros(3);
  aimc.ir=zeros(2);
  lineL.i=zeros(3); // The shunt branch gives the line its own independent current states.
equation
  assert(VNominal>0 and fNominal>0 and tStart>=0 and TLoad>=0 and wLoad>0 and JLoad>0 and RLine>0 and LLine>0,
    "Require positive supply/frequency/inertia/line values and nonnegative load/start time");
  connect(sineVoltage.plug_n,sourceStar.plug_p) annotation(Line(points={{-20,100},{-20,110},{-80,110}},color={0,0,255}));
  connect(sourceStar.pin_n,sourceGround.p) annotation(Line(points={{-100,110},{-120,110}},color={0,0,255}));
  connect(sineVoltage.plug_p,startSwitch.plug_p) annotation(Line(points={{-20,80},{-20,65}},color={0,0,255}));
  connect(startCommand.y,startSwitch.control) annotation(Line(points={{-89,55},{-32,55}},color={255,0,255}));
  connect(startSwitch.plug_n,lineR.plug_p) annotation(Line(points={{-20,45},{-20,30}},color={0,0,255}));
  connect(lineR.plug_n,lineL.plug_p) annotation(Line(points={{-20,10},{-20,-5}},color={0,0,255}));
  connect(lineL.plug_n,currentRMS.plug_p) annotation(Line(points={{-20,-25},{-20,-38}},color={0,0,255}));
  connect(currentRMS.plug_n,terminalBox.plugSupply) annotation(Line(points={{-20,-58},{-20,-65},{-30,-65},{-30,-76}},color={0,0,255}));
  connect(terminalBox.plug_sp,aimc.plug_sp) annotation(Line(points={{-18,-80},{-18,-80}},color={0,0,255}));
  connect(terminalBox.plug_sn,aimc.plug_sn) annotation(Line(points={{-42,-80},{-42,-80}},color={0,0,255}));
  connect(aimc.flange,loadInertia.flange_a) annotation(Line(points={{-10,-100},{20,-100}},color={0,0,0}));
  connect(loadInertia.flange_b,loadTorque.flange) annotation(Line(points={{50,-100},{80,-100}},color={0,0,0}));
  assert(tFault>tStart and tClear>0 and RFault>0,"Require fault after start, positive fault duration and resistance");
  connect(faultCommand.y,faultSwitch.control) annotation(Line(points={{91,65},{120,65},{120,32}},color={255,0,255}));
  connect(lineL.plug_n,faultSwitch.plug_p) annotation(Line(points={{-20,-25},{-20,-30},{20,-30},{20,20},{110,20}},color={0,0,255}));
  connect(faultSwitch.plug_n,faultStar.plug_p) annotation(Line(points={{130,20},{130,20}},color={0,0,255}));
  connect(faultStar.pin_n,faultGround.p) annotation(Line(points={{150,20},{160,20},{160,10}},color={0,0,255}));
  iSource=lineR.i;
  vTerminal=terminalBox.plugSupply.pin.v;
  terminalVRMS=sqrt(sum(vTerminal.^2)/3);
  annotation(uses(Modelica(version="4.1.0")),
    experiment(StartTime=0,StopTime=3,Interval=1e-4,Tolerance=1e-6),
    Diagram(coordinateSystem(extent={{-150,-140},{190,150}}),graphics={
      Text(extent={{-140,147},{150,125}},textString="100 V/phase ideal bus - RL line - Y-connected induction motor",textColor={0,0,127}),
      Text(extent={{-140,-125},{150,-138}},textString="Fault at tFault; clear after tClear; source remains connected",textColor={80,80,80})}),
    Documentation(info="<html><p>Open this .mo in OMEdit. Edit the top-level parameters and simulate. See README.md for physical assumptions, units and independent verification.</p></html>"));
end EmtMachineBaseFault;
