--------------------------------------------------------------------------
-- Name        : Upcon.SQL
-- Description : Updates CONTGNCY_RAW with financial codes for the members
--		last employing unit
-- Author      : 
-- Date Written: 
--$Revision: 6 $
--
-- Modification History
-- --------------------
-- mmddyyyy  name        description
--------------------------------------------------------------------------
-- 11192003  W. Oldroyd	- Modified for consolidation.
-- 05102004  W. Oldroyd - Modified for new report output.
--           J. Sauvageau
-- 03032005  D. Le Gallez - Modified to include UIC 'HOLD' in result sets for output
-- 04152005  D. Le Gallez - Implemented use of FOR UPDATE/WHERE CURRENT OF cursor
--                          for c_upcon cursor in order to eliminate updates of 
--                          multible records.
-- 06072005  D. Le Gallez - Modify the cursor c_upcon to take into consideration 
--                          the EMP_STAT type for conditional selection of emp uic 
--                          instead of parent uic
--
-- 10052005  D. Le Gallez - Modified logic to address ticket T1131.  Cadet member IOs were being displayed
--                          as reserve force GRCs.
--
--------------------------------------------------------------------------
declare 
V_SN            CHAR(9);
V_LINE_SEQ      NUMBER(6);
V_UIC           CHAR(4);
V_FA            CHAR(6);
V_ALMT          CHAR(4);
V_RSRC          CHAR(5);
V_GRC           CHAR(5);
V_C1            NUMBER(3)  := 0;
V_C2            NUMBER(3)  := 0;
V_C3            NUMBER(3)  := 0;
V_C4            NUMBER(3)  := 0;
V_C5            NUMBER(3)  := 0;
V_C_ALL         NUMBER(3)  := 0;
V_C_LEFT        NUMBER(3)  := 0;

cursor c_upcon is
SELECT SN,
       LINE_SEQ,
       NH08_UIC                           UIC,
       NH08_UIC_ATTEND_FA_CD              DFLT_FA,
       NH08_UIC_ATTEND_ALMT_CD            DFLT_FUND,
       NH08_UIC_ATTEND_RSRC_CD            DFLT_ACCT,
       DECODE(NVL(UPPER(NH08_UIC_ATTEND_GRC_CD),'00000'),'NULL','00000',NVL(NH08_UIC_ATTEND_GRC_CD,'00000')) DFLT_IO
FROM   DBAMAINT.CONTGNCY_RAW,
       NH08_UIC,
       PY93_EMP_STAT A
WHERE COMMAND IN ('9997','9998', 'HOLD')
AND   PY93_SERVICE_NUMBER IN (SELECT SN FROM DBAMAINT.CONTGNCY_RAW
                              WHERE SEQUENCE_GROUP = (SELECT MAX(SEQUENCE_GROUP) FROM DBAMAINT.CONTGNCY_RAW)
                              AND   COMMAND IN ('9997','9998','HOLD'))
AND   SN = PY93_SERVICE_NUMBER
AND   SEQUENCE_GROUP = (SELECT MAX(SEQUENCE_GROUP) FROM DBAMAINT.CONTGNCY_RAW)
AND   (PY93_EMP_STAT_FROM_DATE = (SELECT MAX(PY93_EMP_STAT_FROM_DATE)
                                  FROM PY93_EMP_STAT
                                  WHERE PY93_SERVICE_NUMBER = A.PY93_SERVICE_NUMBER
                                  AND PY93_EMP_STAT_TO_DATE IS NOT NULL
                                  AND SUBSTR(PY93_EMP_STAT_EMP_UIC,1,3) <> '999'
                                  AND PY93_EMP_STAT_EMP_UIC != 'HOLD')
       OR
       PY93_EMP_STAT_FROM_DATE = (SELECT MAX(PY93_EMP_STAT_FROM_DATE)
                                  FROM PY93_EMP_STAT
                                  WHERE PY93_SERVICE_NUMBER = A.PY93_SERVICE_NUMBER
                                  AND PY93_EMP_STAT_TO_DATE IS NULL
                                  AND EXISTS(SELECT 'X' FROM PY93_EMP_STAT
                                             WHERE PY93_SERVICE_NUMBER = A.PY93_SERVICE_NUMBER
                                             HAVING COUNT(*) = 1)))
AND   NH08_UIC = DECODE (PY93_EMP_STAT_CD, 'CC', PY93_EMP_STAT_PARENT_UIC, PY93_EMP_STAT_EMP_UIC)
FOR UPDATE OF CONTGNCY_RAW.COMMAND, CONTGNCY_RAW.COST_CENTER, CONTGNCY_RAW.FUND, CONTGNCY_RAW.ACCOUNT, CONTGNCY_RAW.INTERNAL_ORDER;

cursor c_upcon_c1 is
select count(distinct(py93_service_number)) from py93_emp_stat
where   PY93_SERVICE_NUMBER IN (SELECT SN FROM DBAMAINT.CONTGNCY_RAW
                              WHERE SEQUENCE_GROUP = (SELECT MAX(SEQUENCE_GROUP) FROM DBAMAINT.CONTGNCY_RAW)
                              AND   COMMAND IN ('9997','9998','HOLD'));

CURSOR C_COUNT_ALL IS
select count(distinct(SN)) FROM DBAMAINT.CONTGNCY_RAW
                              WHERE SEQUENCE_GROUP = (SELECT MAX(SEQUENCE_GROUP) FROM DBAMAINT.CONTGNCY_RAW)
                              AND   COMMAND IN ('9997','9998','HOLD');

BEGIN

OPEN C_COUNT_ALL;
FETCH C_COUNT_ALL INTO V_C_ALL;
CLOSE C_COUNT_ALL;

OPEN C_UPCON_C1;
FETCH C_UPCON_C1 INTO V_C1;
CLOSE C_UPCON_C1;

   IF V_C1 > 0 THEN

      FOR L_upcon IN C_upcon LOOP
        
           V_SN            := L_upcon.SN;
           V_LINE_SEQ      := L_upcon.LINE_SEQ;
           V_UIC           := L_upcon.UIC;
           V_FA            := L_upcon.DFLT_FA;
           V_ALMT          := L_upcon.DFLT_FUND;
           V_RSRC          := L_upcon.DFLT_ACCT;
           V_GRC           := L_upcon.DFLT_IO;

      UPDATE DBAMAINT.CONTGNCY_RAW
           SET COMMAND             = V_UIC,
               COST_CENTER         = V_FA,
               FUND                = V_ALMT,
               ACCOUNT             = V_RSRC,
               INTERNAL_ORDER      = V_GRC
      WHERE CURRENT OF C_UPCON;

      END LOOP;

   END IF;

END;
/

