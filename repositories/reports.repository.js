import { sequelize } from '../config/database.js';
import { QueryTypes } from 'sequelize';

class ReportsRepository {
  async createReport({
    student_name,
    control_number,
    major,
    report_title,
    work_area,
    pdf_route,
    company_id,
    semester_id,
    keywordsJson,
  }) {
    try {
      await sequelize.query(
        'call residencias.create_report(?, ?, ?, ?, ?, ?, ?, ?, ?, @p_report_id);',
        {
          replacements: [
            student_name,
            control_number,
            major,
            report_title,
            work_area,
            pdf_route,
            company_id,
            semester_id,
            keywordsJson,
          ],
          type: QueryTypes.RAW,
        }
      );

      const [result] = await sequelize.query(
        'SELECT @p_report_id as report_id;',
        {
          type: QueryTypes.SELECT,
        }
      );
      
      return result;
    } catch (error) {
      console.error('Repository error in createReport:', error);
      throw error;
    }
  }

  async getReports() {
    try {
      const result = await sequelize.query('CALL residencias.get_reports();', {
        type: QueryTypes.SELECT,
      });
      return result[0];
    } catch (error) {
      console.error('Repository error in getReports:', error);
      throw error;
    }
  }

  async updateReport({
    report_id,
    student_name,
    major,
    report_title,
    work_area,
    company_id,
    semester_id,
    pdf_route,
    keywordsJson,
  }) {
    const result = await sequelize.query(
      'CALL residencias.update_report(?, ?, ?, ?, ?, ?, ?, ?, ?);',
      {
        replacements: [
          report_id,
          student_name,
          major,
          report_title,
          work_area,
          company_id,
          semester_id,
          pdf_route ?? null,
          keywordsJson,
        ],
        type: QueryTypes.SELECT,
      }
    );
    return result[0][0];
  }

  async deleteReport({ report_id }) {
    const result = await sequelize.query('CALL residencias.delete_report(?);', {
      replacements: [report_id],
      type: QueryTypes.SELECT,
    });
    return result[0][0];
  }
  
  async getReportPdfRoute({ report_id }) {
    const result = await sequelize.query('CALL residencias.get_report_pdf_route(?);', {
      replacements: [report_id],
      type: QueryTypes.SELECT,
    });
    return result.length > 0 ? result[0][0] : null;
  }
  
  async getReportsByKeyword({ keyword }) {
    const result = await sequelize.query('CALL residencias.get_reports_by_keyword(?);', {
        replacements: [keyword],
        type: QueryTypes.SELECT
    });
    return result[0];
  }
}

export default new ReportsRepository();