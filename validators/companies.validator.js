import Joi from 'joi';

class CompaniesValidator {
  createCompany() {
    return Joi.object({
      company_name: Joi.string().max(150).trim().required(),
      description: Joi.string().allow(null, ''),
      address: Joi.string().max(150).allow(null, ''),
      phone_number: Joi.string().max(30).allow(null, ''),
      email: Joi.string().email().max(100).allow(null, '')
    });
  }

  getCompanies() {
    return Joi.object({});
  }

  updateCompany() {
    return Joi.object({
      company_id: Joi.number().required(),
      company_name: Joi.string().max(150).trim().required(),
      description: Joi.string().allow(null, ''),
      address: Joi.string().max(150).allow(null, ''),
      phone_number: Joi.string().max(30).allow(null, ''),
      email: Joi.string().email().max(100).allow(null, '')
    });
  }

  deleteCompany() {
    return Joi.object({
      company_id: Joi.number().required(),
    });
  }
}

export default new CompaniesValidator();