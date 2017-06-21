   
public with sharing class Report_KeyRatioProTest 
{
	
	public map<string, boolean> fieldVisibilityMap {get;set;}
	public string jsonVisiblity {get {return JSON.serialize(fieldVisibilityMap);}}
	public Id curOfficeId {get;set;}
	public Id usrId {get;set;}
	public static List<SelectOption> franchiseeList {get;set;}
	public List<officeWrapper>officeLst {get;set;}
	public list<id> officeIdlst;
	public Map<id, List<empWrapper>> empData {get;set;}    // Map<accountId, List<employee wrapper>>
	public string statusFilter {get;set;}
	public set<id> selectedEmpIds {get;set;}
	public integer selectedEmpCnt {get;set;}
	public integer totalEmpCnt {get;set;}
	public integer fieldCnt {get;set;}
	public string fldJSON {get;set;}
	public boolean showInactiveEmps {get;set;}
	
	public class fieldWrapper
	{
		public string name		{get;set;}
		public boolean visible	{get;set;}
		public Integer sOrder	{get;set;}
		
		public fieldWrapper (string nm, boolean vis, Integer ord )
		{
			this.name = nm;
			this.visible = vis;
			this.sOrder = ord;
		}
	}
	
	public map<string, fieldWrapper> fieldInfo 	{get;set;}
 	
	public class officeWrapper
	{
		public string officeNm		{get;set;}
		public id officeId			{get;set;}
		public account accntRec		{get;set;}
		
		public officeWrapper( string nm, id oid, account rec)
		{
			this.officeNm = nm;
			this.officeId = oid;
			this.accntRec = rec;
		}
	}
	
	public class empWrapper 
	{
		public string empName 		{get;set;}
		public id empId 			{get;set;}
		public boolean isSelected 	{get;set;}
		public id accountId 		{get;set;}	
		public string officeNm 		{get;set;}
		public string empStatus		{get;set;}
		public date hireDate		{get;set;}
		
		public empWrapper( string name, id empId, boolean sel, id accId, string offNm, string empStatus, date hired)
		{
			this.empName = name;
			this.empId = empId;
			this.isSelected = sel;
			this.accountId = accid;
			this.officeNm = offNm;
			this.empStatus = empStatus;
			this.hireDate = hired;
		}
	}
	
    public class ReportOutput
    {
        public boolean haveData {get;set;}
        public List<sObject> result {get; set;}			// List<contact>

        public Map<Id, sObject> empRec {get; set;}		// {EMPID}, {CONTACT RECORD}

        public Map<Id, Decimal> grades {get; set;}
        
        public Map<Id, Integer> jobsCompleted {get; set;}
        
        public Map<Id, Integer> jobsRedoCount {get;set;}

        public Map<Id, Decimal> thrilledPercent {get; set;}
        
        public Map<Id, Decimal> thrilledRecCount {get; set;}

        public Map<Id, Decimal> employeeAttrition {get; set;}

        public Map<Id, Decimal> netPromoterScore {get; set;}

        public Map<Id, Decimal> totalHrs {get; set;}
        
        public Map<Id, Integer> unExcusedCount {get;set;}
        
        public Map<Id, Integer> ExcusedCount {get;set;}
        
        public Map<Id, Decimal> revenueCompleted {get; set;}
        
        public Map<Id, Decimal> revenueCanceled {get; set;}
        
        public Map<Id, Decimal> payrollJob {get; set;}
        
        public Map<Id, Decimal> payrollNonJob {get; set;}		// DISPATCH PAYROLL RECORDS
        
        public Map<Id, Integer> distinctClientCnt {get;set;}	// DISTINCT CLIENT COUNTS OVER PERIOD USED FOR ATTRITION
        
        public Map<Id, Integer> attritionCnt {get;set;}			// ATTRITION HIT-COUNTS OVER PERIOD 
        
        public Map<id, Decimal> durationHours {get;set;}		// SUM OF DURATION WORKED FOR JOBS
        
        public Map<id, Decimal> durationWorkPayroll {get;set;}	// SUM OF HOURS WORKED ONLY ATTRIBUTED TO WORKING HOURS
        
        //map of field labels and names
        //public Map<String, String> columns {get; set;}
        
    }	
	
	public static List<empWrapper> EmpSelectList {get;set;}
	
	public id Franchisee {get;set;}
	public Key_Ratio_Emp_Setup__c setupRec {get;set;}
	public static DateTime now = DateTime.now();
    public static Boolean isFranchisee {get;set;}
    public static Double offset{ get 
    	{ 
		    string strOffset = System.now().format('Z');
			string strOffsetHours = strOffset.substring(0,3);
		
			if(strOffsetHours.startsWith('+'))
			{
			  strOffsetHours = strOffsetHours.substring(1);
			}
			
			integer iMinutes = 100 * integer.valueOf(strOffset.substring(3));
			double dOffset = double.valueOf(strOffsetHours + '.' + ((iMinutes) / 60));
	    	return dOffset;
    	}
    } 
  
      
    public Boolean displayReport { get; set; }
    public static Id[] franchiseeListSelected { get; set; }
    //public static transient Map<String, Decimal> totalsMap { get; set; }
    
    
    public Report_KeyRatioProTest()
    {   		
    	system.debug('In Constructor...');
    	fieldVisibilityMap = new map<string, boolean>(); 
    	officeLst = new List<officeWrapper>();
    	officeIdlst = new list<id>();
    	empData = new map<id, List<empWrapper>>();   			// MAP<OFFICE ID, LIST<EMP WRAPPER>>
    	franchiseeList = new List<SelectOption>();
    	selectedEmpIds = new set<id>();
    	showInactiveEmps = false;
    	
    	usrId = UserInfo.getUserId();
    	isFranchisee = ExecutionContext.getIsFranchiseeUser();
    	
    	// PULL IN ANY SAVED SETTING INFORMATION FOR THE USER...
    	
		loadConfiguration();
    	buildFieldInfo();

    	
    	system.debug('Setup Data Rec = ' + setupRec);
    	
        displayReport = false;
        
        getFranchisees();						// QUERY TO PULL IN OFFICE INFORMATION...
        getEmpsForFranchisees();				// BUILD EMPLOYEE MAPS BASED ON OFFICES
        
    }
    
    public void loadConfiguration()
    {
    	system.debug('in loadConfiguration...');
    	String flds = utilities.getSelectFieldsForObject('Key_Ratio_Emp_Setup__c');
    	string sql = 'SELECT ' + flds + ' FROM Key_Ratio_Emp_Setup__c WHERE User__c = \'' + usrId + '\' limit 1';
    	system.debug('Query = ' + sql);
    	setupRec = new Key_Ratio_Emp_Setup__c();   	
    	List<Key_Ratio_Emp_Setup__c> setupData = Database.query( sql );
    	
    	system.debug('Called query...');
    	if (setupData.size() == 0)
    	{
    		system.debug('No setup data... initializing');
    		setupRec.user__c = usrId;
    		setupRec.val_Status_Active__c = true;
    		setupRec.val_Status_Inactive__c = true; 
    	}
    	else
    	{
    		system.debug('Have Setup Data = ' + setupData);
    		setupRec = setupData[0];
    		system.debug('after setupRec invocation');
    		if (setupRec.val_Selected_Pros__c.length() > 0) 
    		{    			
    			selectedEmpIds = (Set<Id>)JSON.deserialize(setupRec.val_Selected_Pros__c, Set<Id>.Class);
    			system.debug('Loaded Selected Emp count = ' + selectedEmpIds.size());
    		}
    	}    	
    }
    
    public void  buildFieldInfo()
    {   	
    	system.debug('in buildFieldInfo...');
    	updateFldVisibility();

    	if (setupRec.columnInfo__c == null)
    	{
    		fieldInfo = new map<string, fieldWrapper>();
    		Integer i = 0;
    		system.debug('Initializing field map...');
    		fieldInfo.put('Attrition__c', new fieldWrapper('Attrition', setupRec.fld_Attrition_Rate__c, i++));
    		fieldInfo.put('JobCosting__c', new fieldWrapper('Job Costing', setupRec.fld_Job_Costing_Percentage__c, i++));
    		fieldInfo.put('deltaMinHrs__c', new fieldWrapper('Delta Min Hrs', setupRec.fld_Delta_From_Min_Hours__c, i++));
    		fieldInfo.put('JobsCompleted__c', new fieldWrapper('Jobs Completed', setupRec.fld_Num_Jobs_Completed__c, i++));
    		fieldInfo.put('Hours__c', new fieldWrapper('Avg Hrs/Week', setupRec.fld_Total_Hrs_Rcvd__c, i++));
    		fieldInfo.put('Minimum_Hours_Requested__c', new fieldWrapper('Min Hrs Rqst', setupRec.fld_Min_Hrs_Requested__c, i++));
    		fieldInfo.put('Grade__c', new fieldWrapper('MPU Avg Score', setupRec.fld_MPU_Score_Avg__c, i++));
    		fieldInfo.put('Insurance_Expiration_Date__c', new fieldWrapper('Auto Ins Expire', setupRec.fld_Auto_Ins_Exp__c, i++));
    		fieldInfo.put('Drivers_License_Expiration__c', new fieldWrapper('Drivers Lic Expire', setupRec.fld_Drivers_Lic_Exp__c, i++));
    		fieldInfo.put('Total_Days_Employed_Grouping__c', new fieldWrapper('Days Emp Group', setupRec.fld_Tot_Days_Emp_Grouping__c, i++));
    		fieldInfo.put('Total_Days_Employed__c', new fieldWrapper('Days Employed', setupRec.fld_Tot_Days_Employed__c, i++));
    		fieldInfo.put('Date_Of_Hire__c', new fieldWrapper('Hire Date', setupRec.fld_Hire_Date__c, i++));
    		fieldInfo.put('Recruiting_Source__c', new fieldWrapper('Recruiting Src', setupRec.fld_Recruiting_Src__c, i++));
    		fieldInfo.put('ThrilledPercent__c', new fieldWrapper('% Thrilled', setupRec.fld_Percent_Thrilled__c, i++));
    		fieldInfo.put('RedoCnt__c', new fieldWrapper('Re-Cleans', setupRec.fld_Num_Recleans_Caused__c, i++));
    		fieldInfo.put('UnExcusedCount__c', new fieldWrapper('Unexcused', setupRec.fld_Num_Unexcused_Absenses__c, i++));
    		fieldInfo.put('ExcusedCount__c', new fieldWrapper('Excused', setupRec.fld_Num_Excused_Absences__c, i++)); 
    		fieldInfo.put('NetPromoterScore__c', new fieldWrapper('Net Promoter', setupRec.fld_Net_Promoter_Score__c, i++));     		
    		fieldInfo.put('Status__c', new fieldWrapper('Status', setupRec.fld_Status__c, i++));
    		fieldInfo.put('Abbrev_Name__c', new fieldWrapper('Office', true, i++));
    		fieldInfo.put('Name', new fieldWrapper('Full Name', setupRec.fld_Full_Name__c, i++));
    		fieldInfo.put('LastName', new fieldWrapper('Last Name', setupRec.fld_Last_Name__c, i++));
    		fieldInfo.put('FirstName', new fieldWrapper('First Name', setupRec.fld_First_Name__c, i++));
    		fieldInfo.put('Id', new fieldWrapper('Id', false, i++));		
    		fieldInfo.put('AccountId', new fieldWrapper('AccountId', false, i++));
    		fieldInfo.put('revenueCompleted__c', new fieldWrapper('RevComplete', false, i++));
    		fieldInfo.put('revenueCanceled__c', new fieldWrapper('RevCanceled', false, i++));
    		fieldInfo.put('payrollJob__c', new fieldWrapper('payrollJob', false, i++));
    		fieldInfo.put('payrollNonJob__c', new fieldWrapper('payrollNonJob', false, i++));
    		fieldInfo.put('DeltaHours__c', new fieldWrapper('Delta Hrs', setupRec.fld_Over_Under_Delta__c, i++));
    		
    		
    		fldJSON = JSON.serialize( fieldInfo );
    		fieldCnt = i;  		  		
    	}
    	else
    	{
    		system.debug('Loading field map...');
    		fldJSON = setupRec.columnInfo__c;
    		fieldCnt = 29;
    	}
    	
    	
    	system.debug('Field Info - Count = ' + fieldCnt + ' Map = ' + fldJSON);
    }
   
    
    public void saveSettings()
    {
    	system.debug('in SaveSettings method... setupRec = ' + setupRec);
    	upsert setupRec;
    }
    

	private void updateFldVisibility()
	{
		system.debug('In updateFldVisibility...');
		// UPDATE THE FIELD VISIBILITY MAP
		
		fieldVisibilityMap.clear();
		fieldVisibilityMap.put('Status__c', setupRec.fld_Status__c);
		fieldVisibilityMap.put('Total_Days_Employed__c', setupRec.fld_Tot_Days_Employed__c);
		fieldVisibilityMap.put('Total_Days_Employed_Grouping__c', setupRec.fld_Tot_Days_Emp_Grouping__c);
		fieldVisibilityMap.put('Date_Of_Hire__c', setupRec.fld_Hire_Date__c);
		fieldVisibilityMap.put('FirstName', setupRec.fld_First_Name__c);
		fieldVisibilityMap.put('LastName', setupRec.fld_Last_Name__c);
		fieldVisibilityMap.put('Name', setupRec.fld_Full_Name__c);
		fieldVisibilityMap.put('Drivers_License_Expiration__c', setupRec.fld_Drivers_Lic_Exp__c);
		fieldVisibilityMap.put('Insurance_Expiration_Date__c', setupRec.fld_Auto_Ins_Exp__c);	
		fieldVisibilityMap.put('Grade__c', setupRec.fld_MPU_Score_Avg__c);	
		fieldVisibilityMap.put('Minimum_Hours_Requested__c', setupRec.fld_Min_Hrs_Requested__c);
		fieldVisibilityMap.put('Recruiting_Source__c', setupRec.fld_Recruiting_Src__c);
		fieldVisibilityMap.put('Hours__c', setupRec.fld_Total_Hrs_Rcvd__c);
		fieldVisibilityMap.put('Id', false);
		fieldVisibilityMap.put('AccountId', false);
		fieldVisibilityMap.put('Abbrev_Name__c', true);
		fieldVisibilityMap.put('ThrilledPercent__c', setupRec.fld_Percent_Thrilled__c);
		fieldVisibilityMap.put('RedoCnt__c', setupRec.fld_Num_Recleans_Caused__c);
		fieldVisibilityMap.put('UnExcusedCount__c', setupRec.fld_Num_Unexcused_Absenses__c);
		fieldVisibilityMap.put('ExcusedCount__c', setupRec.fld_Num_Excused_Absences__c);
		fieldVisibilityMap.put('NetPromoterScore__c', setupRec.fld_Net_Promoter_Score__c); 	
		fieldVisibilityMap.put('revenueCompleted__c', false);
		fieldVisibilityMap.put('revenueCanceled__c', false);
		fieldVisibilityMap.put('payrollJob__c', false);
		fieldVisibilityMap.put('payrollNonJob__c', false);
		fieldVisibilityMap.put('JobCosting__c', setupRec.fld_Job_Costing_Percentage__c);
		fieldVisibilityMap.put('deltaMinHrs__c', setupRec.fld_Delta_From_Min_Hours__c);
		fieldVisibilityMap.put('Attrition__c', setupRec.fld_Attrition_Rate__c);
		fieldVisibilityMap.put('DeltaHours__c', setupRec.fld_Over_Under_Delta__c);
	}

	public pageReference applyFilters()
	{
		applyEmpInfo();
		return null;
	}
	
	public pageReference applyEmpInfo()
	{
		system.debug('in applyEmpInfo method...SETUP Rec = ' + setupRec);
		
		getSelectedEmps();
		system.debug('Saved Selected Emp count = ' + selectedEmpIds.size());
		String JSONString = JSON.serialize(selectedEmpIds);
		setupRec.val_Selected_Pros__c = JSONString;
		upsert setupRec;
		//updateFldVisibility();
		buildFieldInfo();	
		return null;
	}
	
	public pageReference updateFieldOrder()
	{
		system.debug('In updateFieldOrder...');
		loadConfiguration();
		buildFieldInfo();
		return null;
	}
    
    public void getEmpsForFranchisees()
    {
    	system.debug('In getEmpsForFranchisees...OfficeIds = ' + officeIdLst);
    	system.debug('RecordTypeId = ' +  RecordTypeIds.FRANCHISEE_CONTACT_RECORDTYPEID);
    	totalEmpCnt = 0;
    	boolean isChecked = false;
    	for (contact c: [SELECT CreatedDate, date_of_hire__c, AccountId, AccountName__c, Account.Abbrev_Name__c, FirstName, Franchisee_Name__c, Id, Inactive_Effective_Date__c,
    	                              LastName, Name, Net_Promoter_Category__c, Office__c, RecordTypeId, Status__c  
    	                         FROM Contact
    	                        WHERE recordTypeId = :RecordTypeIds.FRANCHISEE_CONTACT_RECORDTYPEID
    	                          AND accountId IN :officeIdlst 
    	                     ORDER BY lastName]) 
    	{
    		//system.debug('Name:' + c.Name + ', Account Id:' + c.accountId + ', Account Name:' + c.accountName__c);
    		if (empData.get(c.accountId) == Null)
    		{
    			empData.put(c.AccountId, new List<empWrapper>());		// CREATE TOP LEVEL MAP
    				
    		}
    		isChecked = false;
    		//system.debug('Checking for selected record for ' + c.Name + '(' + c.status__c + ')');
    		if (selectedEmpIds.contains( c.Id ))
    		{
    			isChecked = true;
    		}
    		else if ( ((c.Status__c == 'Active') && (setupRec.val_Status_Active__c == true)) ||
    		          ((c.Status__c == 'Inactive') && (setupRec.val_Status_Inactive__c == true))
    		        )
    		{
    			isChecked = true;
    		}
    		else
    		{
    			system.debug('--- Did not find record for ' + c.Name);
    		}

    		empData.get(c.AccountId).add( new empWrapper(c.Name, c.Id, isChecked, c.accountId, c.account.abbrev_name__c, c.status__c, c.date_of_hire__c) );	
    		totalEmpCnt++;

    	}
    	getSelectedEmps();
    	//system.debug('Emp Data = ' + empData);
    }    

	public void  filterActiveEmpStatus() 
	{
		system.debug('in filterActiveEmpStatus: ');
		system.debug('statusfilter = ' + statusFilter);
		system.debug('Active = ' + setupRec.val_Status_Active__c);
		system.debug('Inactive = ' + setupRec.val_Status_Inactive__c);
		
		boolean checkVal = setupRec.val_Status_Active__c;
		
		for (Id officeId : officeIdLst)
		{
			system.debug('Processing office: ' + officeId);
			for (empWrapper emp : empData.get( officeId ))
			{
				if (emp.empStatus == 'Active')
				{
					emp.isSelected = checkVal;
				}
			}
		}
		getSelectedEmps();
		
	}
	
	public void setOfficeEmps()
	{
		if (curOfficeId ==  null) return;
		
		for (empWrapper emp : empData.get( curOfficeId ))
		{
			emp.isSelected = true;
		}		
	}
	
	public void clearOfficeEmps()
	{
		if (curOfficeId ==  null) return;
		
		for (empWrapper emp : empData.get( curOfficeId ))
		{
			emp.isSelected = false;
		}		
	}	
	
	public void  filterInactiveEmpStatus() 
	{		
		system.debug('in filterEmpStatus: ');
		system.debug('statusfilter = ' + statusFilter);
		system.debug('Active = ' + setupRec.val_Status_Active__c);
		system.debug('Inactive = ' + setupRec.val_Status_Inactive__c);
		
		boolean checkVal = setupRec.val_Status_Inactive__c;
		
		for (Id officeId : officeIdLst)
		{
			system.debug('Processing office: ' + officeId);
			for (empWrapper emp : empData.get( officeId ))
			{
				if (emp.empStatus == 'Inactive')
				{
					emp.isSelected = checkVal; 
				}
			}
		}
		getSelectedEmps();
	}
	
	public void getSelectedEmps()
	{
		system.debug('In getSelectedEmps...officeIdLst = ' + officeIdLst);
		selectedEmpIds.clear();
		
		for (Id officeId : officeIdLst)
		{
			system.debug('Getting Emps for office (' + officeId + ')');
			if (empData.get(officeId) != null)
			{
				for (empWrapper emp : empData.get( officeId ))
				{
					//system.debug('Emp:' + emp.empName + ', Selected:' + emp.isSelected);
					if (emp.isSelected)
					{
						selectedEmpIds.add(emp.empId);
					}
				}
			}
		}
		selectedEmpCnt = selectedEmpIds.size();
	}	
    
	public void getFranchisees()			// pickval is a class of Id and Name
    {
        //List<Franchise.pickVal> franchPicks = new List<Franchise.pickVal>();
        
        // LOOP THROUGH ALL PARENTS AND CHILDREN AND BULD LIST FOR ALL ACCOUNTS
       
    	List<Id> parentIds = new List<Id>();
    	Map<Id, Account> parentMap = new Map<Id, Account>();
    	Map<Id, List<Account>> parentChildren = new Map<Id, List<Account>>();
        for (Account a : [SELECT Id, Name, Type, ParentId
                          FROM Account
                          WHERE RecordTypeId=:RecordTypeIds.FRANCHISEE_ACCOUNT_RECORDTYPEID
                           AND Type IN ('Franchisee Parent', 'Franchisee Single Location', 'Franchisee Branch')
                           AND Exclude_from_KRR__c = false AND Parent.Exclude_from_KRR__c = false
                          ORDER BY Name ASC])
        { 	
        	//Doing this so we can sort by parents/single branches and then children
        	if (a.Type == 'Franchisee Branch'){
        		if (parentChildren.get(a.ParentId) == null) parentChildren.put(a.ParentId, new List<Account>());
        		parentChildren.get(a.ParentId).add(a);
        	} else {
        		parentMap.put(a.Id, a);
        		parentIds.add(a.Id);
        	}
            
        }//end account loop
        
        for (Id parentId : parentIds)
        {
        	Account a = parentMap.get(parentId);
        	//franchPicks.add(new Franchise.pickVal(a.Id, a.Name));
        	officeWrapper offRec = new officeWrapper(a.Name, a.id, a);
        	officeLst.add( offRec );
        	officeIdlst.add( a.id);
        	
        	if (parentChildren.get(parentId) != null)
        	{
            	for (Account childAcc : parentChildren.get(parentId))
            	{
            		//franchPicks.add(new Franchise.pickVal(childAcc.Id, childAcc.Name));
            		officeWrapper offRecChild = new officeWrapper( childAcc.name, childAcc.Id, childAcc);
            		officeLst.add( offRecChild );
            		officeIdlst.add( childAcc.Id);	            	
            	}
        	}
        }
        system.debug('Parent Map = ' + parentMap);
        system.debug('Parent-Children Map = ' + parentChildren);
        system.debug('account keys = ' + officeLst);
    }


    private static Map<String, String> parseQueryFields(String query, String objectName) {
        // Get the select fields
        List<String> fields = query.substring(6, query.indexOf('FROM')).split(',');
      
        SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
    
        System.debug('fields>>'+fields);

        // Get the describe field information of the SObject from the query so that
        // we can save the api name and label that will be used for the column information
        // of our report table
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        system.debug('fieldMap>>'+fieldMap);
        Map<String, String> columnInfo = new Map<String, String>();
        Schema.DescribeFieldResult fieldResult;
        for (String field : fields) {
            // Trim the field from our fields list so that any leading/trailing spaces
            // and carriage returns are not included when getting the field info
            try{
                fieldResult = fieldMap.get(field.trim()).getDescribe();
                columnInfo.put(fieldResult.getName(), fieldResult.getLabel());

            } catch(Exception e){
                //eat it
            }
            
        }

        return columnInfo;
    }


    @RemoteAction 
    public static Boolean configureUser( String curUser ) 	
    {
    	system.debug('In configureUser - ' + curUser );
    	

		system.debug('Building office list...');
		
		List<Account>officeLst = 
		                [SELECT Id
                           FROM Account
                          WHERE RecordTypeId=:RecordTypeIds.FRANCHISEE_ACCOUNT_RECORDTYPEID
                            AND Type IN ('Franchisee Single Location', 'Franchisee Branch')
                            AND Exclude_from_KRR__c = false AND Parent.Exclude_from_KRR__c = false
                       ORDER BY Name ASC];
		

    	List<Contact> contactLst =  
    					[SELECT Id  
    	                   FROM Contact
    	                  WHERE recordTypeId = :RecordTypeIds.FRANCHISEE_CONTACT_RECORDTYPEID
    	                    AND status__c = 'Active'
    	                    AND accountId IN :officeLst];
    	
    	String JSONEmps='[';
    	Integer i = 0;
    	if (contactLst.size() > 0)
    	{
    		for (Contact c : contactLst)
    		{
    			if (i > 0)
    			{
    				JSONEmps += ',';
    			}
    			JSONEmps += '"' + c.Id + '"';
    			i++;
    			
    		}
    		JSONEmps += ']';
    		system.debug('JSON Emps = ' + JSONEmps);
    	}
    	
    	Key_Ratio_Emp_Setup__c newRec = new Key_Ratio_Emp_Setup__c();
    	
    	newRec.User__c = curUser;
    	newRec.val_Selected_Pros__c = JSONEmps;

      	INSERT newRec;
     	String flds = utilities.getSelectFieldsForObject('Key_Ratio_Emp_Setup__c');
    	string sql = 'SELECT Id FROM Key_Ratio_Emp_Setup__c WHERE User__c = \'' + curUser + '\' limit 1';
    	system.debug('Query = ' + sql);
    	Key_Ratio_Emp_Setup__c setupRec = new Key_Ratio_Emp_Setup__c();   	
    	List<Key_Ratio_Emp_Setup__c> setupData = Database.query( sql );     	  		
    	if (setupData.size() > 0)
    	{
    		return true;
    	}	
    	
    	return false;
    }

    @RemoteAction 
    public static Boolean saveSortOrder( String curUser, String sortStr) 	
    {
    	system.debug('In saveSortOrder - ' + curUser + ', ' + sortStr);
    	
    	
    	List<Key_Ratio_Emp_Setup__c> configRec = [SELECT Id, columnInfo__c FROM Key_Ratio_Emp_Setup__c WHERE User__c = :curUser limit 1];
    	if (configRec.size() > 0)
    	{
    		configRec[0].columnInfo__c = sortStr;
    		update configRec;
    	}
    	
    	return true;
    }

    @RemoteAction @ReadOnly
    public static ReportOutput runReport( String userId, String empIds, string sd, string ed, Integer weeks ) 	
    {
    	system.debug('in Run Report for user ' + userId);
    	ReportOutput output = new ReportOutput();
    	output.haveData = false;
    	 	 	
     	Date startDate = date.parse(sd); 
     	Date endDate = date.parse(ed); 
 
 		system.debug('In run report -- start:' + startDate + ', end:' + endDate);
 		
     	String startDateString =  DateTime.newInstance(startDate.year(),startDate.month(),startDate.day()).format('yyyy-MM-dd');
     	String endDateString = DateTime.newInstance(endDate.year(),endDate.month(),endDate.day()).format('yyyy-MM-dd');
     	
     	system.debug('start Date = ' + startDateString + ', end Date = ' + endDateString );
     	
    	// -----------------------------------------------------------------------------------------------------------------
        // GATHER THE LIST OF PRO IDS THAT WILL BE USED FOR THE VARIOUS QUERIES...
        // -----------------------------------------------------------------------------------------------------------------
        
		empIds = empIds.removeStart('[');
		empIds = empIds.removeEnd(']');
		empIds = empIds.deleteWhitespace();
		
		system.debug('in Run Report method...param =  StartDate=' + sd + ', Enddate=' + ed);
    	List<string> selectedEmpIds = empids.split(',');
    	
    	// -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE BASIC INFORMATION FROM THE CONTACT OBJECT...
        // -----------------------------------------------------------------------------------------------------------------
    	
        List<contact> contactLst = [SELECT Id, lastname, Name, firstName, AccountName__c, Account.Abbrev_Name__c, Inactive_Effective_Date__c, Date_Of_Hire__c, Insurance_Expiration_Date__c, 
        								   Recruiting_Source__c, total_days_employed__c, Total_Days_Employed_Grouping__c, status__c, 
        								   Drivers_License_Expiration__c, Minimum_Hours_Requested__c, AccountId
        				              FROM contact
        				             WHERE Id in :selectedEmpIds];
        
        if (contactLst.size() > 0)
        {
        	output.haveData = true;
        }
        
        output.result = contactLst;									// STORE QUERY RESULTS INTO REPORT OUTPUT OBJECT
        output.empRec = new Map<id, sObject>();						// BUILD THE EMPLOYEE RECORD MAP USED BY THE DATATABLE LOGIC
        for(sObject s : output.result) 								// FOR EACH CONTACT IN THE RESULSTS
        {
        	system.debug('Processing contact ' + s.Id + ', Record: ' + s);
            //system.debug('s in loop is>>'+s);
            output.empRec.put(s.id, s);								// ADD THE ID AND RECORD INFORMATION
        }
        
        
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE MPU AVERAGE SCORE FOR EACH PRO...
        // -----------------------------------------------------------------------------------------------------------------
        
        String query = '   SELECT contact__c, avg(grade__c) grade__c ' + 
                       '     FROM lms_course__C ' + 
                       '    WHERE status__c=\'Complete\' AND contact__c IN :selectedEmpIds ' +
                       ' GROUP BY contact__c';
        
        List<Sobject> gradeResult = Database.query(query);			// GET THE RESULTS FROM THE QUERY
        output.grades = new Map<id, Decimal>();						// INITIALIZE THE REPORT OUTPUT GRADE CONTAINER
        for(sObject s : gradeResult)								// FOR EACH CONTACT WITH GRADE INFORMATION
        {
            ID id = (id)(s.get('Contact__c'));						// GET THE CONTACT ID
            Decimal grade = (Decimal)(s.get('grade__c'));			// GET THE GRADE
            if (grade==null) 
            {
            	grade=0.00;	
            }			
            grade=grade.setScale(2);								// FORMAT AVERAGE SCORE TO 2 DECIMAL PLACES
            output.grades.put(id, grade);							// STORE THE ID AND AVG MPU SCORE (GRADE) TO REPORT OUTPUT
        }   
      
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE TOTAL HOURS WORKED BASED ON SPECIFIED START/END DATES
        // ----------------------------------------------------------------------------------------------------------------- 
        
        system.debug('start Date = ' + startDateString + ', end Date = ' + endDateString ); 
        decimal weekCnt = 0.0;
        
 		AggregateResult[] groupedResults =
 				[SELECT employee__c, SUM(hours__c) totHours 
 		           FROM PayRoll__c
 		          WHERE employee__c IN :selectedEmpIds
 		            AND (date_worked__c >= :startDate )
 		            AND (date_worked__c <= :endDate )
 		          GROUP BY employee__c];

		output.totalHrs = new Map<id, Decimal>();
		for (AggregateResult ar : groupedResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('employee__c');
			system.debug('--------- Processing Emp = ' + empId + ' -------------');
			contact c 	 = (contact)output.empRec.get( empId ); 
			system.debug('got contact ' + c.Id + ', hire date = ' + c.date_of_hire__c);
			
			date startDt = startDate;										// INITIALIZE START DATE TO REPORT START DATE
			date endDt   = endDate;										// INITIALIZE END DATE TO REPORT END DATE
			
			system.debug('Start date = ' + startDt);
			system.debug('End Date ' + endDt);
			
			if (c.date_of_hire__c != null)
			{
				if (c.date_of_hire__c > startDate)							// IF EMP HIRE DATE IS AFTER REPORT START DATE
				{
					startDt = c.date_of_hire__c;							// ADJUST START DATE FOR THIS CALCULATION
					system.debug('...adjusting start date to ' + startDt);
				}
			}
			
			if (c.Inactive_Effective_Date__c != null)
			{
				if (c.Inactive_Effective_Date__c < endDate)					// IF EMP INACTIVE DATE IS PRIOR TO REPORT END DATE
				{
					endDt = c.Inactive_Effective_Date__c;					// ADJUST END DATE FOR THIS CALCULATION
					system.debug('...adjusting end date to ' + endDt);
				}
			}
			system.debug('Doing day diff between: (' + startDt + ') and (' + endDt + ')');
			weekCnt = (startDt.daysBetween(endDt)/7.0).setScale(2);			// DETERMINE # WEEKS BETWEEN START AND END
			if (weekCnt < 1.0)												// ACCOUNT FOR SOMEONE HIRED AND INACTIVE IN SAME WEEK.. DIFF < 1
			{
				weekCnt = 1.0;
			}
			system.debug('Adjusted Week Cnt = ' + weekCnt);
			
			Decimal hrs  = (Decimal)(ar.get('totHours'));
			if (hrs == null)
			{
				hrs = 0.0;
			}
			else
			{
				system.debug('Calculating ' + hrs + '/' + weekCnt);
				hrs = (hrs/weekCnt);										// GET AVERAGE HOURS PER WEEK BASED ON TIME RANGE
				system.debug('new Hours = ' + hrs);
			}
			hrs = hrs.setScale(2);
		    output.totalHrs.put( empId, hrs );
		}
        
        //output.columns.put('Hours__c', 'Hrs Worked');

        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE # JOBS COMPLETED FOR THE SPECIFIED TIME RANGE...
        // ----------------------------------------------------------------------------------------------------------------- 
        
        system.debug('start Date = ' + startDateString + ', end Date = ' + endDateString );
               
 		AggregateResult[] jobCountResults =
 				[SELECT Contact__c, count(job__r.name) totCompleted 
 		           FROM job_Contact__c
 		          WHERE Contact__c IN :selectedEmpIds
 		            AND (job__r.start_date__c >= :startDate )
 		            AND (job__r.end_date__c <= :endDate )
 		            AND (job__r.status__c = 'Completed')
 		          GROUP BY Contact__c];

		output.jobsCompleted = new Map<id, Integer>();
		for (AggregateResult ar : jobCountResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('contact__c');
			Integer cnt  = (Integer)(ar.get('totCompleted'));
			if (cnt == null)
			{
				cnt = 0;
			}
			//system.debug('Tot cnt: empId = ' + empId + ', cnt = ' + cnt);
		    output.jobsCompleted.put( empId, cnt );
		}
        
        
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE PERCENTAGE THRILLED FOR THE SPECIFIED TIME RANGE...
        // ----------------------------------------------------------------------------------------------------------------- 
        
        system.debug('Getting thrilled data... EmpId list = ' + selectedEmpIds);
        system.debug('start Date = ' + startDateString + ', end Date = ' + endDateString );
               
 		AggregateResult[] thrilledResults =
 				[SELECT  contact__c, sum(service_feedback__r.thrilled__c) sumThrilled, count(service_feedback__r.thrilled__c) cntThrilled
 		           FROM Feedback_Contact__c
 		          WHERE contact__c IN :selectedEmpIds
 		          GROUP BY contact__c];

		output.thrilledPercent = new Map<id, decimal>();
		output.thrilledRecCount = new Map<id, decimal>();
		for (AggregateResult ar : thrilledResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('contact__c');
			decimal cnt  = (decimal)(ar.get('cntThrilled'));
			decimal thrilledPercent = 0.0;
			decimal thrilledSum = 0.0;
			
			if (cnt == null)
			{
				cnt = 0;
			}
			if (cnt > 0)
			{
				thrilledSum = (decimal)(ar.get('sumThrilled'));
				thrilledPercent = (decimal)((thrilledSum / cnt) * 100.00).setScale(2);
			}
			system.debug('Thrilled Info: empId = ' + empId + ', cnt = ' + cnt + ', percentage = ' + thrilledPercent);
		    output.thrilledPercent.put( empId, thrilledPercent );
		    output.thrilledRecCount.put( empId, cnt );
		}        


        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE # RECLEANS DONE FOR THE SPECIFIED TIME RANGE...
        // ----------------------------------------------------------------------------------------------------------------- 
           
        system.debug('Getting # reCleans...'); 
        output.jobsRedoCount = new Map<id, Integer>();
        list<job__c> redoLst = [SELECT Job_Redo__c, Id, Name 		
        	   FROM Job__c 
        	  WHERE is_Redo__c = true 
        	    AND Start_Date__c >= :startDate
        	    AND End_Date__c <= :endDate
        	];
        
        set<id> redoSet = new set<id>();	
        if (redoLst.size() > 0)
        {
        	for (job__c j : redoLst)
        	{
        		redoSet.add( j.job_Redo__c);		// ADD THE ORIGINAL JOB THAT CAUSED THE RECLEAN
        	}
 
	 		AggregateResult[] redoResults =
	 				[SELECT Contact__c, count(Id) cnt     
	 		           FROM job_Contact__c
	 		          WHERE Contact__c IN :selectedEmpIds
	 		            AND Job__c IN :redoSet
	 		          GROUP BY Contact__c];
	
			
			for (AggregateResult ar : redoResults)  					// GET THE RESULTS FROM THE QUERY
			{
				Id empId     = (Id) ar.get('contact__c');
				Integer cnt  = (Integer)(ar.get('cnt'));
				if (cnt == null)
				{
					cnt = 0;
				}
				system.debug('Tot cnt: empId = ' + empId + ', Redocnt = ' + cnt);
			    output.jobsRedoCount.put( empId, cnt );
			}
        }
		
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE # UNEXCUSED ABSENCES ...
        // ----------------------------------------------------------------------------------------------------------------- 
           
        system.debug('Getting # Unexcused Absences...');    
 		AggregateResult[] unExcusedResults =
 				[SELECT Contact__c, count(Id) cnt     
 		           FROM Employee_Availability__c
 		          WHERE Contact__c IN :selectedEmpIds
 		            AND (start_date__c >= :startDate )
 		            AND (end_date__c <= :endDate )
 		            AND (Type__c = 'Unexcused Absence')
 		          GROUP BY Contact__c];

		output.unExcusedCount = new Map<id, Integer>();
		for (AggregateResult ar : unExcusedResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('contact__c');
			Integer cnt  = (Integer)(ar.get('cnt'));
			if (cnt == null)
			{
				cnt = 0;
			}
			system.debug('Tot cnt: empId = ' + empId + ', cnt = ' + cnt);
		    output.unExcusedCount.put( empId, cnt );
		}	
		
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE # EXCUSED ABSENCES ...
        // ----------------------------------------------------------------------------------------------------------------- 
           
        system.debug('Getting # Excused Absences...');    
 		AggregateResult[] ExcusedResults =
 				[SELECT Contact__c, count(Id) cnt     
 		           FROM Employee_Availability__c
 		          WHERE Contact__c IN :selectedEmpIds
 		            AND (start_date__c >= :startDate )
 		            AND (end_date__c <= :endDate )
 		            AND (Type__c <> 'Unexcused Absence')
 		          GROUP BY Contact__c];

		output.ExcusedCount = new Map<id, Integer>();
		for (AggregateResult ar : ExcusedResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('contact__c');
			Integer cnt  = (Integer)(ar.get('cnt'));
			if (cnt == null)
			{
				cnt = 0;
			}
			system.debug('Tot cnt: empId = ' + empId + ', cnt = ' + cnt);
		    output.ExcusedCount.put( empId, cnt );
		}			
 
 
       

        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE # NET PROMOTER SCORE
        // ----------------------------------------------------------------------------------------------------------------- 
           
        system.debug('Getting NET PROMOTER INFO...');    
 		AggregateResult[] promoterResults =
 				[SELECT  contact__c, count(id) totcnt, sum(service_Feedback__r.isPromoter__c) promoterCnt, 
 						  sum(service_Feedback__r.isPassive__c) passiveCnt, sum(service_Feedback__r.isRetractor__c) retractorCnt 
				   FROM Feedback_Contact__c 
				  WHERE Contact__c IN :selectedEmpIds
				    AND (service_Feedback__r.job__r.start_date__c >= :startDate )
 		            AND (service_Feedback__r.job__r.end_date__c <= :endDate )
				    AND service_Feedback__r.How_Likely_To_Recommend_Numeric__c <> null 
			   GROUP BY contact__c ];

		output.netPromoterScore = new Map<id, Decimal>();
		for (AggregateResult ar : promoterResults)  					// GET THE RESULTS FROM THE QUERY
		{
			decimal promoterCnt = 0.0;
			decimal retractorCnt = 0.0;
			decimal netScore = 0.0;
			
			Id empId        = (Id) ar.get('contact__c');
			Integer totCnt  = (Integer)(ar.get('totCnt'));
			if (totCnt == null)
			{
				totCnt = 0;
			}
			if (totCnt > 0)
			{
			    promoterCnt = (decimal)(ar.get('promoterCnt'));
				retractorCnt = (decimal)(ar.get('retractorCnt'));
				netScore = (((promoterCnt-retractorCnt)/totCnt) *100).setScale(0);
			}
			system.debug('Tot cnt: empId = ' + empId + ', totcnt = ' + totCnt + ', Promoter=' + promoterCnt + ', Retractor=' + retractorCnt + ', Net Score=' + netScore);
		    output.netPromoterScore.put( empId, netScore );
		}	


        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE REVENUE FOR THE JOBS COMPLETED FOR THE SPECIFIED TIME RANGE...
        // ----------------------------------------------------------------------------------------------------------------- 
       
        system.debug('start Date = ' + startDateString + ', end Date = ' + endDateString );
               
 		AggregateResult[] jobRevenueResults =
 			[select contact__c, sum(job__r.Charges_Subtotal__c) subTotal from Job_Contact__c
 		          where contact__c IN :selectedEmpIds 
 		            AND (job__r.start_date__c >= :startDate )
 		            AND (job__r.end_date__c <= :endDate )
 		            AND (job__r.status__c = 'Completed')
 		            AND (job__r.is_dispatch__c = false)
 		          GROUP BY contact__c];	          

		output.revenueCompleted = new Map<id, decimal>();
		for (AggregateResult ar : jobRevenueResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('contact__c');
			decimal amnt  = (decimal)(ar.get('subTotal'));
			if (amnt == null)
			{
				amnt = 0.0;
			}
		    output.revenueCompleted.put( empId, amnt );
		    system.debug('Putting completed revenue ... empId:' + empId + ', amnt:' + amnt);
		}
		
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE REVENUE FOR THE JOBS CANCELED FOR THE SPECIFIED TIME RANGE...
        // ----------------------------------------------------------------------------------------------------------------- 
               
 		AggregateResult[] jobCancelRevenueResults =
 			[select contact__c, sum(job__r.Charges_Subtotal__c) subTotal from Job_Contact__c
 		          where contact__c IN :selectedEmpIds 
 		            AND (job__r.start_date__c >= :startDate )
 		            AND (job__r.end_date__c <= :endDate )
 		            AND ((job__r.status__c = 'Canceled') OR (job__r.status__c = 'Canceled with Fees'))
 		            AND (job__r.is_dispatch__c = false)
 		          GROUP BY contact__c];	          

		output.revenueCanceled = new Map<id, decimal>();
		for (AggregateResult ar : jobCancelRevenueResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId     = (Id) ar.get('contact__c');
			decimal amnt  = (decimal)(ar.get('subTotal'));
			if (amnt == null)
			{
				amnt = 0.0;
			}
		    output.revenueCanceled.put( empId, amnt );
		    system.debug('Putting canceled revenue ... empId:' + empId + ', amnt:' + amnt);
		}	
		
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE JOB-RELATED PAYROLL FOR THE PERIOD...
        // ----------------------------------------------------------------------------------------------------------------- 
               
 		AggregateResult[] payrollJobResults =
 			[select  Employee__c, sum(Total_Amount__c) totAmnt from Payroll__c  
 			  where employee__c IN :selectedEmpIds  
 			  and date_worked__c >= :startDate 
 			  and date_worked__c <= :endDate 
 			  and role__c <> 'Dispatch' 
 			  Group by Employee__c];	          

		output.payrollJob = new Map<id, decimal>();
		for (AggregateResult ar : payrollJobResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId      = (Id) ar.get('Employee__c');
			decimal amnt  = (decimal)(ar.get('totAmnt'));
			if (amnt == null)
			{
				amnt = 0.0;
			}
		    output.payrollJob.put( empId, amnt );
		    system.debug('Putting job related payroll ... empId:' + empId + ', amnt:' + amnt);
		}	
		
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE NON-JOB-RELATED PAYROLL FOR THE PERIOD...
        // ----------------------------------------------------------------------------------------------------------------- 
               
 		AggregateResult[] payrollNonJobResults =
 			[select  Employee__c, sum(Total_Amount__c) totAmnt from Payroll__c  
 			  where employee__c IN :selectedEmpIds  
 			  and date_worked__c >= :startDate 
 			  and date_worked__c <= :endDate 
 			  and role__c = 'Dispatch' 
 			  Group by Employee__c];	          

		output.payrollNonJob = new Map<id, decimal>();
		for (AggregateResult ar : payrollNonJobResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId      = (Id) ar.get('Employee__c');
			decimal amnt  = (decimal)(ar.get('totAmnt'));
			if (amnt == null)
			{
				amnt = 0.0;
			}
		    output.payrollNonJob.put( empId, amnt );
		    system.debug('Putting job related payroll ... empId:' + empId + ', amnt:' + amnt);
		}	
		
        // -----------------------------------------------------------------------------------------------------------------
        // ATTRITION DATA COLLECTION:
        //
        // QUERY AND COLLECT THE NUMBER OF DISTINCT CLIENTS PROCESSED DURING PERIOD...
        // ----------------------------------------------------------------------------------------------------------------- 
               
 		AggregateResult[] clientCountResults =
 			[SELECT Contact__c, COUNT_DISTINCT( job__r.client_Account__c) cnt 
 			   FROM job_contact__c 
 			  WHERE job__r.status__c = 'Completed' 
 			    AND  job__r.start_Date__c >= :startDate 
 			    AND job__r.start_Date__c <= :endDate
 			    AND job__r.kind__c != 'OTC Job' 
 			    AND contact__c IN :selectedEmpIds  
 			GROUP BY Contact__c ];	          

		output.distinctClientCnt = new Map<id, integer>();
		for (AggregateResult ar : clientCountResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId      = (Id) ar.get('Contact__c');
			integer cnt  = (integer)(ar.get('cnt'));
			if (cnt == null)
			{
				cnt = 0;
			}
		    output.distinctClientCnt.put( empId, cnt );
		    system.debug('Putting Distinct Account cnts ... empId:' + empId + ', cnt:' + cnt);
		}									

		// AT THIS POINT, WE HAVE (ABOVE), THE NUMBER OF DISTINCT ACCOUNTS THAT EACH PRO SERVICED FOR THE PERIOD,
		// NOW WE NEED TO GET THE DISTINCT COUNTS OF ATTRITION HITS FOR EACH PRO FOR THE PERIOD.  THIS SHOULD JUST
		// BE A COUNT OF  THE NUMBER OF ENTRIES THAT EACH PRO HAS A RECORD IN THE PRO_ATTRITION TABLE FOR THE 
		// SPECIFIED PERIOD...
		
		output.attritionCnt = new Map<id, integer>();
		
 		AggregateResult[] attritionResults =
 			 [SELECT contact__c, count(id) tot 
			    FROM Pro_Attrition__c 
			   WHERE Attrition_Date__c >= :startDate  
				 AND Attrition_Date__c <= :endDate
				 AND contact__c IN :selectedEmpIds
		    GROUP BY contact__c];	          

		system.debug('Getting Attrition Counts...');
		
		for (AggregateResult ar : attritionResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId = (Id) ar.get('Contact__c');
			Integer tot  = (integer)(ar.get('tot'));
			if (tot == null)
			{
				tot = 0;
			}
		    output.attritionCnt.put( empId, tot );
		    system.debug('Putting Attrition Count ... empId:' + empId + ', tot:' + tot);
		}				
		
        // -----------------------------------------------------------------------------------------------------------------
        // QUERY AND COLLECT THE OVER/UNDER DELTA FOR HOURS WORKED VS PAYROLL HOURS PAID...
        // ----------------------------------------------------------------------------------------------------------------- 

 		AggregateResult[] durationHrsResults =
 			[ SELECT contact__c, SUM(job__r.duration__c) tot
				FROM Job_Contact__c 
			   WHERE contact__c IN :selectedEmpIds 
				 AND job__r.start_date__c >= :startDate
				 AND job__r.start_date__c <= :endDate 
				 AND job__r.kind__c <> 'OTC Job'
				 AND job__r.status__c = 'Completed'  
				 AND job__r.Type__c <> 'Dispatch'
			GROUP BY contact__c];	          

		output.durationHours = new Map<id, decimal>();
		for (AggregateResult ar : durationHrsResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId    = (Id) ar.get('Contact__c');
			decimal tot  = (decimal)(ar.get('tot'));
			if (tot == null)
			{
				tot = 0.0;
			}
		    output.durationHours.put( empId, tot );
		    system.debug('Putting Duration Worked ... empId:' + empId + ', tot:' + tot);
		}									

 		AggregateResult[] workingPayrollResults =
 				[SELECT employee__c, SUM(hours__c) totHours 
 		           FROM PayRoll__c
 		          WHERE employee__c IN :selectedEmpIds
 		            AND (date_worked__c >= :startDate )
 		            AND (Job__c != null)
 		            AND (date_worked__c <= :endDate )
 		            AND job__r.kind__c <> 'OTC Job'
 		            AND job__r.status__c = 'Completed' 
 		            AND Role__c NOT IN ('Travel', 'Dispatch')
 		          GROUP BY employee__c];
		
		output.durationWorkPayroll = new Map<id, decimal>();

		for (AggregateResult ar : workingPayrollResults)  					// GET THE RESULTS FROM THE QUERY
		{
			Id empId    = (Id) ar.get('employee__c');
			decimal tot  = (decimal)(ar.get('totHours'));
			if (tot == null)
			{
				tot = 0.0;
			}
		    output.durationWorkPayroll.put( empId, tot );
		    system.debug('Putting Duration Payroll Hours Worked ... empId:' + empId + ', tot:' + tot);
		}
			

        // -----------------------------------------------------------------------------------------------------------------
        // AFTER ALL INFORMATION IS STORED IN THE EMPREC MAP, GO THROUGH THE VARIOUS FILTER RECORDS AND REMOVE PROS
        // THAT DON'T MEET THE REQUIREMENTS
        // -----------------------------------------------------------------------------------------------------------------        
                 
        system.debug('OUTPUT = ' + output);  
        
           
        return output;
    } 
    
       
} 